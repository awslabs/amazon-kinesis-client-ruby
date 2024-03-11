#
#  Copyright 2014 Amazon.com, Inc. or its affiliates. All Rights Reserved.
#  SPDX-License-Identifier: Apache-2.0

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

    def shutdown_requested(checkpointer)
      checkpointer.checkpoint
    end
  end

  class TestRecordProcessorV2 < Aws::KCLrb::V2::RecordProcessorBase

    def init_processor(shard_id)
      # no-op
    end

    def shutdown_requested(shutdown_requested_input)
      shutdown_requested_input.checkpointer.checkpoint
    end

    def process_records(process_records_input)
      last_seq = nil
      records = process_records_input.records
      records.each do |record|
        last_seq = record['sequenceNumber']
      end

      if last_seq
        checkpointer = process_records_input.checkpointer
        begin
          checkpointer.checkpoint(last_seq)
        rescue CheckpointError => cpe
          if cpe.value == 'ThrottlingException'
            checkpointer.checkpoint(last_seq)
          else
            raise
          end
        end
      end
    end

  end

  describe KCLProcess do

    input_specs = [
      {:method => :init_processor, :action => 'initialize', :input => '{"action":"initialize","shardId":"shard-000001","sequenceNumber":123456789}'},
      {:method => :process_records, :action => 'processRecords', :input => '{"action":"processRecords","records":[],"millisBehindLatest":0}'},
      {:method => :shutdown, :action => 'shutdownRequested', :input => '{"action":"shutdownRequested","reason":"TERMINATE"}'}
    ]
    versions = [1, 2]

    describe "#action_response" do

      before(:each) do
        @processor = double(RecordProcessorBase)
      end

      input_specs.each do |input_spec|
        versions.each do |version|
          it "V#{version} should respond to #{input_spec[:method]} action by invoking the corresponding processor's method and write a status message to the output IO" do
            allow(@processor).to receive(:version).and_return(version)
            action_response_common_test(input_spec[:method], input_spec[:action], input_spec[:input], version)
          end
        end
      end

      def action_response_common_test(method, action, input, version)
        if method == :shutdown
          expected_shutdown_input = version == 1 ? Aws::KCLrb::CheckpointerImpl : Aws::KCLrb::V2::ShutdownRequestedInput
          allow(@processor).to receive(:shutdown_requested).with(expected_shutdown_input).and_return(nil)
        else
          expect(@processor).to receive(method).once
        end
        input = StringIO.new(input)
        output = StringIO.new
        error = StringIO.new
        driver = KCLProcess.new(@processor, input, output, error)
        driver.run

        expected_output = %Q[{"action":"status","responseFor":"#{action}"}]
        expect(output.string.gsub(/\s+/, "")).to eq(expected_output.gsub(/\s+/, ""))
        expect(error.string).to eq("")
        expect(input.eof?).to eq(true)
      end

    end

    describe "#run" do
      versions.each do |version|
        it "V#{version} should process a normal stream of actions and produce expected output" do
          input_string = <<-INPUT
{"action":"initialize","shardId":"shardId-123","sequenceNumber":123}
{"action":"processRecords","records":[{"data":"bWVvdw==","partitionKey":"cat","sequenceNumber":"456"}],"millisBehindLatest":"0"}
{"action":"checkpoint","sequenceNumber":"456","error":"ThrottlingException"}
{"action":"checkpoint","sequenceNumber":"456"}
{"action":"shutdownRequested","reason":"TERMINATE"}
{"action":"checkpoint","sequenceNumber":"456"}
          INPUT

          # NOTE: The first checkpoint is expected to fail
          #       with a ThrottlingException and hence the
          #       retry.
          expected_output_string = <<-OUTPUT
{"action":"status","responseFor":"initialize"}
{"action":"checkpoint","sequenceNumber":"456"}
{"action":"checkpoint","sequenceNumber":"456"}
{"action":"status","responseFor":"processRecords"}
{"action":"checkpoint","sequenceNumber":null}
{"action":"status","responseFor":"shutdownRequested"}
          OUTPUT
          processor = version == 1 ? TestRecordProcessor.new : TestRecordProcessorV2.new
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
end
