#! /usr/bin/env ruby
#
#  Copyright 2014 Amazon.com, Inc. or its affiliates. All Rights Reserved.
# 
#  Licensed under the Amazon Software License (the "License").
#  You may not use this file except in compliance with the License.
#  A copy of the License is located at
# 
#  http://aws.amazon.com/asl/
# 
#  or in the "license" file accompanying this file. This file is distributed
#  on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
#  express or implied. See the License for the specific language governing
#  permissions and limitations under the License.

require 'aws/kclrb'
require 'base64'
require 'tmpdir'
require 'fileutils'

# @api private
# A sample implementation of the {Aws::KCLrb::RecordProcessorBase RecordProcessor}.
#
# All it does is write the data to an output stream. Be careful not to use
# the `$stdout` as it's used to communicate with the {https://github.com/awslabs/amazon-kinesis-client/blob/master/src/main/java/com/amazonaws/services/kinesis/multilang/package-info.java MultiLangDaemon}.
# If you use `$stderr` instead the MultiLangDaemon would echo the output
# to its own standard error stream.
class SampleRecordProcessor < Aws::KCLrb::RecordProcessorBase
  # @param output [IO, String] If a string is provided, it's assumed to be the path
  #   to an output directory. That directory would be created and permissions to write
  #   to it are asserted.
  def initialize(output=$stderr)
    @close = false
    if output.is_a?(String)
      @output_directory = output
      # Make sure the directory exists and that we can
      # write to it. If not, this will fail and processing
      # can't start.
      FileUtils.mkdir_p @output_directory
      probe_file = File.join(@output_directory, '.kclrb_probe')
      FileUtils.touch(probe_file)
      FileUtils.rm(probe_file)
    elsif output
      # assume it's an IO
      @output = output
    else
      fail "Output destination cannot be nil"
    end
  end

  # (see Aws::KCLrb::RecordProcessorBase#init_processor)
  def init_processor(shard_id)
    unless @output
      @filename = File.join(@output_directory, "#{shard_id}-#{Time.now.to_i}.log")
      @output = open(@filename, 'w')
      @close = true
    end
  end

  # (see Aws::KCLrb::RecordProcessorBase#process_records)
  def process_records(records, checkpointer)
    last_seq = nil
    records.each do |record|
      begin
        @output.puts Base64.decode64(record['data'])
        @output.flush
        last_seq = record['sequenceNumber']
      rescue => e
        # Make sure to handle all exceptions.
        # Anything you write to STDERR will simply be echoed by parent process
        STDERR.puts "#{e}: Failed to process record '#{record}'"
      end
    end
    checkpoint_helper(checkpointer, last_seq)  if last_seq
  end

  # (see Aws::KCLrb::RecordProcessorBase#shutdown)
  def shutdown(checkpointer, reason)
    checkpoint_helper(checkpointer)  if 'TERMINATE' == reason
  ensure
    # Make sure to cleanup state
    @output.close  if @close
  end

  private
  # Helper method that retries checkpointing once.
  # @param checkpointer [Aws::KCLrb::Checkpointer] The checkpointer instance to use. 
  # @param sequence_number (see Aws::KCLrb::Checkpointer#checkpoint) 
  def checkpoint_helper(checkpointer, sequence_number=nil)
    begin
      checkpointer.checkpoint(sequence_number)
    rescue Aws::KCLrb::CheckpointError => e
      # Here, we simply retry once.
      # More sophisticated retry logic is recommended.
      checkpointer.checkpoint(sequence_number) if sequence_number
    end
  end
end

if __FILE__ == $0
  # Start the main processing loop
  record_processor = SampleRecordProcessor.new(ARGV[1] || File.join(Dir.tmpdir, 'kclrbsample'))
  driver = Aws::KCLrb::KCLProcess.new(record_processor)
  driver.run
end

