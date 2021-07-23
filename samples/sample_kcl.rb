#! /usr/bin/env ruby
#
#  Copyright 2019 Amazon.com, Inc. or its affiliates. All Rights Reserved.
#  SPDX-License-Identifier: Apache-2.0

require 'aws/kclrb'
require 'base64'
require 'date'

# @api private
# A sample implementation of the {Aws::KCLrb::RecordProcessorBase RecordProcessor}.
#
# All it does is write the data to an output stream. Be careful not to use
# the `$stdout` as it's used to communicate with the {https://github.com/awslabs/amazon-kinesis-client/blob/master/src/main/java/com/amazonaws/services/kinesis/multilang/package-info.java MultiLangDaemon}.
# If you use `$stderr` instead the MultiLangDaemon would echo the output
# to its own standard error stream.
class SampleRecordProcessor < Aws::KCLrb::V2::RecordProcessorBase
  # (see Aws::KCLrb::V2::RecordProcessorBase#init_processor)
  def init_processor(initialize_input)
    @shard_id = initialize_input.shard_id
    @checkpoint_freq_seconds = 10
  end

  # (see Aws::KCLrb::V2::RecordProcessorBase#process_records)
  def process_records(process_records_input)
    last_seq = nil
    records = process_records_input.records

    records.each do |record|
      data = Base64.decode64(record['data'])
      process_record(record, data)
      last_seq = record['sequenceNumber']
    end

    # Checking if last sequenceNumber is not nil and if it has been more than @check_freq_seconds before checkpointing.
    if last_seq &&
        ((@last_checkpoint_time.nil?) || ((DateTime.now - @last_checkpoint_time) * 86400 > @checkpoint_freq_seconds))
      checkpoint_helper(process_records_input.checkpointer, last_seq)
      @last_checkpoint_time = DateTime.now
    end
  end

  # (see Aws::KCLrb::V2::RecordProcessorBase#lease_lost)
  def lease_lost(lease_lost_input)
    #   Lease was stolen by another Worker.
  end

  # (see Aws::KCLrb::V2::RecordProcessorBase#shard_ended)
  def shard_ended(shard_ended_input)
    checkpoint_helper(shard_ended_input.checkpointer)
  end

  # (see Aws::KCLrb::V2::RecordProcessorBase#shutdown_requested)
  def shutdown_requested(shutdown_requested_input)
    checkpoint_helper(shutdown_requested_input.checkpointer)
  end

  private

  # Helper method that retries checkpointing once.
  # @param checkpointer [Aws::KCLrb::Checkpointer] The checkpointer instance to use.
  # @param sequence_number (see Aws::KCLrb::Checkpointer#checkpoint)
  def checkpoint_helper(checkpointer, sequence_number = nil)
    begin
      checkpointer.checkpoint(sequence_number)
    rescue Aws::KCLrb::CheckpointError => e
      # Here, we simply retry once.
      # More sophisticated retry logic is recommended.
      checkpointer.checkpoint(sequence_number) if sequence_number
    end
  end

  # Called for each record that is passed to record_processor.
  # @param record Kinesis record
  def process_record(record, data)
    begin
      if data.nil?
        length = 0
      else
        length = data.length
      end
      STDERR.puts("ShardId: #{@shard_id}, Partition Key: #{record['partitionKey']}, Sequence Number:#{record['sequenceNumber']}, Length of data: #{length}")
    rescue => e
      STDERR.puts "#{e}: Failed to process record '#{record}'"
    end
  end
end

if __FILE__ == $0
  # Start the main processing loop
  driver = Aws::KCLrb::KCLProcess.new(SampleRecordProcessor.new)
  driver.run
end
