module Aws
  module KCLrb
    module V2
      # @abstract
      # Input object for RecordProcessorBase#init_processor method.
      class InitializeInput
        attr_reader :shard_id, :sequence_number

        def initialize(shard_id, sequence_number)
          @shard_id = shard_id
          @sequence_number = sequence_number
        end
      end

      # @abstract
      # Input object for RecordProcessorBase#process_records method.
      class ProcessRecordsInput
        attr_reader :records, :millis_behind_latest, :checkpointer

        def initialize(records, millis_behind_latest, checkpointer = nil)
          @records = records
          @millis_behind_latest = millis_behind_latest
          @checkpointer = checkpointer
        end
      end

      # @abstract
      # Input object for RecordProcessorBase#lease_lost method.
      class LeaseLostInput
      end

      # @abstract
      # Input object forRecordProcessorBase#shard_ended method.
      class ShardEndedInput
        attr_reader :checkpointer

        def initialize(checkpointer = nil)
          @checkpointer = checkpointer
        end
      end

      # @abstract
      # Input object for RecordProcessorBase#shutdown_requested method.
      class ShutdownRequestedInput
        attr_reader :checkpointer

        def initialize(checkpointer = nil)
          @checkpointer = checkpointer
        end
      end
    end
  end
end
