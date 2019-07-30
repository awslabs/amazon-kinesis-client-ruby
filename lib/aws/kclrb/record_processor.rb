#
#  Copyright 2019 Amazon.com, Inc. or its affiliates. All Rights Reserved.
#  SPDX-License-Identifier: Apache-2.0

module Aws
  module KCLrb
    # @abstract
    # Base class for implementing a record processor.
    # 
    # A `RecordProcessor` processes a shard in a stream. See {https://github.com/awslabs/amazon-kinesis-client/blob/master/src/main/java/com/amazonaws/services/kinesis/clientlibrary/interfaces/IRecordProcessor.java the corresponding KCL interface}.
    # Its methods will be called as follows:
    #
    # 1. {#init_processor} will be called once
    # 2. {#process_records} will be called zero or more times
    # 3. {#shutdown} will be called if this {https://github.com/awslabs/amazon-kinesis-client/blob/master/src/main/java/com/amazonaws/services/kinesis/multilang/package-info.java MultiLangDaemon}
    #    instance loses the lease to this shard
    class RecordProcessorBase
      # @abstract
      # Called once by a KCLProcess before any calls to process_records.
      #
      # @param shard_id [String] The shard id that this processor is going to be working on.
      def init_processor(shard_id)
        fail NotImplementedError.new
      end

      # @abstract
      # Called by a KCLProcess with a list of records to be processed and a checkpointer
      # which accepts sequence numbers from the records to indicate where in the stream
      # to checkpoint.
      #
      # @param records [Array<Hash>] A list of records that are to be processed. A record 
      #   looks like:
      #
      #   ```
      #   {"data":"<base64 encoded string>","partitionKey":"someKey","sequenceNumber":"1234567890"}
      #   ```
      #
      #   Note that `data` attribute is a base64 encoded string. You can use `Base64.decode64`
      #   in the `base64` module to get the original data as a string.
      # @param checkpointer [Checkpointer] A checkpointer which accepts a sequence
      #   number or no parameters.
      def process_records(records, checkpointer)
        fail NotImplementedError.new
      end

      # @abstract
      # Called by a KCLProcess instance to indicate that this record processor
      # should shutdown. After this is called, there will be no more calls to
      # any other methods of this record processor.
      #
      # @param checkpointer [Checkpointer] A checkpointer which accepts a sequence
      #   number or no parameters.
      # @param reason [String] The reason this record processor is being shutdown,
      #   can be either `TERMINATE` or `ZOMBIE`.
      #
      #   - If `ZOMBIE`, clients should not checkpoint because there is possibly
      #     another record processor which has acquired the lease for this shard.
      #   - If `TERMINATE` then `checkpointer.checkpoint()` (without parameters)
      #     should be called to checkpoint at the end of the shard so that this
      #     processor will be shutdown and new processor(s) will be created to
      #     for the child(ren) of this shard.
      def shutdown(checkpointer, reason)
        fail NotImplementedError.new
      end

      # @abstract
      # Called by a KCLProcess instance to indicate that this record processor
      # is requesting a shutdown. This method should be overriden if required.
      #
      # @param checkpointer [Checkpointer] A checkpointer which accepts a sequence
      #   number or no parameters.
      def shutdown_requested(checkpointer)
      end

      def version
        1
      end
    end

    module V2
      # @abstract
      # Base class for implementing a record processor.
      #
      # A `RecordProcessor` processes a shard in a stream. See {https://github.com/awslabs/amazon-kinesis-client/blob/master/src/main/java/com/amazonaws/services/kinesis/clientlibrary/interfaces/IRecordProcessor.java the corresponding KCL interface}.
      # Its methods will be called as follows:
      #
      # 1. {#init_processor} will be called once
      # 2. {#process_records} will be called zero or more times
      # 3. {#lease_lost} will be called zero to one time
      # 4. {#shard_ended} will be called zero or more times
      # 5. {#shutdown_requested} will be called zero to one time
      class RecordProcessorBase
        # @abstract
        # Called once by a KCLProcess before any calls to process_records.
        #
        # @param initialize_input [InitializeInput] Initialize processor input
        #   object
        def init_processor(initialize_input)
          fail NotImplementedError.new
        end

        # @abstract
        # Called by a KCLProcess with a list of records to be processed and a
        # checkpointer which accepts sequence numbers from the records to
        # indicate where in the stream to checkpoint.
        #
        # @param record_processor_input [RecordProcessorInput] Process records
        #   input object
        def process_records(process_records_input)
          fail NotImplementedError.new
        end

        # @abstract
        # Called by a KCLProcess instance to indicate that this record processor
        # should shutdown. After this is called, there will be no more calls to
        # any other methods of this record processor.
        #
        # @param lease_lost_input [LeaseLostInput] Lease lost input object
        #
        #    - Clients should not checkpoint because there is possibly another
        #      record processor which has acquired the lease for this shard.
        def lease_lost(lease_lost_input)
          fail NotImplementedError.new
        end

        # @abstract
        # Called by a KCLProcess instance to indicate that this record processor
        # should shutdown. After this is called, there will be no more calls to
        # any other methods of this record processor.
        #
        # @param shard_ended_input [ShardEndedInput] Shard ended input object
        #
        #   - Clients need to checkpoint at this time.
        def shard_ended(shard_ended_input)
          fail NotImplementedError.new
        end

        # @abstract
        # Called by a KCLProcess instance to indicate that this record processor
        # is requesting a shutdown. This method should be overriden if required.
        #
        # @param shutdown_requested_input [ShutdownRequestedInput]
        def shutdown_requested(shutdown_requested_input)
        end

        def version
          2
        end
      end

      class V2ToV1Adapter < Aws::KCLrb::V2::RecordProcessorBase
        def initialize(processor)
          @processor = processor
        end

        def init_processor(initialize_input)
          @processor.init_processor(initialize_input.shard_id)
        end

        def process_records(process_records_input)
          @processor.process_records(process_records_input.records,
                                     process_records_input.checkpointer)
        end

        def lease_lost(lease_lost_input)
          @processor.shutdown(nil, 'ZOMBIE')
        end

        def shard_ended(shard_ended_input)
          @processor.shutdown(shard_ended_input.checkpointer, 'TERMINATE')
        end

        def shutdown_requested(shutdown_requested_input)
          @processor.shutdown_requested(shutdown_requested_input.checkpointer)
        end
      end
    end
  end
end