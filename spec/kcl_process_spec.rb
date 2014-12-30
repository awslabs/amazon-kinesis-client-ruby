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

require 'aws/kclrb/kcl_process'
require 'aws/kclrb/record_processor'

module Aws::KCLrb
  # Dummy test class.
  # The {#process_reocrds} method will retry the checkpointing call
  #   in case of a throttling exception.
  class TestRecordProcessor < RecordProcessorBase
    def init_processor(shard_id)
      # no-op
    end

    def process_records(records, checkpointer)
      seq = records[0]['sequenceNumber']
      begin
        checkpointer.checkpoint(seq)
      rescue CheckpointError => cpe
        if cpe.value == 'ThrottlingException'
          checkpointer.checkpoint(seq)
        else
          raise
        end
      end
    end

    def shutdown(checkpointer, reason)
      checkpointer.checkpoint  if reason == 'TERMINATE'
    end
  end

  describe KCLProcess do
    describe "#run" do
      it "should respond to each action by invoking the corresponding processor's method and write a status message to the output IO" do
        input_specs = [
          {:method => :init_processor, :action => 'initialize', :input => '{"action":"initialize","shardId":"shard-000001"}'},
          {:method => :process_records, :action => 'processRecords', :input => '{"action":"processRecords","records":[]}'},
          {:method => :shutdown, :action => 'shutdown', :input => '{"action":"shutdown","reason":"TERMINATE"}'},
        ]
        # pick any of the actions randomly to avoid writing a test for each
        input_spec = input_specs.sample
        processor = double(RecordProcessorBase)
        expect(processor).to receive(input_spec[:method]).once
        input = StringIO.new(input_spec[:input])
        output = StringIO.new
        error = StringIO.new
        driver = KCLProcess.new(processor, input, output, error)
        driver.run

        expected_output = %Q[{"action":"status","responseFor":"#{input_spec[:action]}"}]
        expect( output.string.gsub(/\s+/, "") ).to eq(expected_output.gsub(/\s+/, ""))
        expect( error.string ).to eq("")
        expect( input.eof? ).to eq(true)
      end
      it "should process a normal stream of actions and produce expected output" do
        input_string = <<-INPUT
{"action":"initialize","shardId":"shardId-123"}
{"action":"processRecords","records":[{"data":"bWVvdw==","partitionKey":"cat","sequenceNumber":"456"}]}
{"action":"checkpoint","checkpoint":"456","error":"ThrottlingException"}
{"action":"checkpoint","checkpoint":"456"}
{"action":"shutdown","reason":"TERMINATE"}
{"action":"checkpoint","checkpoint":"456"}
        INPUT

        # NOTE: The first checkpoint is expected to fail
        #       with a ThrottlingException and hence the
        #       retry.
        expected_output_string = <<-OUTPUT
{"action":"status","responseFor":"initialize"}
{"action":"checkpoint","checkpoint":"456"}
{"action":"checkpoint","checkpoint":"456"}
{"action":"status","responseFor":"processRecords"}
{"action":"checkpoint","checkpoint":null}
{"action":"status","responseFor":"shutdown"}
        OUTPUT
        processor = TestRecordProcessor.new
        input = StringIO.new(input_string)
        output = StringIO.new
        error = StringIO.new
        driver = KCLProcess.new(processor, input, output, error)
        driver.run

        # outputs should be same modulo some whitespaces
        expect( output.string.gsub(/\s+/, "") ).to eq(expected_output_string.gsub(/\s+/, ""))
        expect( error.string ).to eq("")
        expect( input.eof? ).to eq(true)
      end
    end
  end
end
