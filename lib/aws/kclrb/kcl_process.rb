#
#  Copyright 2014 Amazon.com, Inc. or its affiliates. All Rights Reserved.
#  SPDX-License-Identifier: Apache-2.0

require 'aws/kclrb/io_proxy'
require 'aws/kclrb/checkpointer'
require 'aws/kclrb/messages'
require 'aws/kclrb/record_processor'

module Aws
  module KCLrb
    # Error raised if the {KCLProcess} received an input action that it
    # could not parse or it could not handle.
    class MalformedAction < RuntimeError;
    end

    # Entry point for a KCL application in Ruby.
    #
    # Implementers of KCL applications in Ruby should instantiate this
    # class and invoke the {#run} method to start processing records.
    class KCLProcess
      # @param processor [RecordProcessorBase] A record processor
      #   to use for processing a shard.
      # @param input [IO] An `IO`-like object to read input lines from.
      # @param output [IO] An `IO`-like object to write output lines to.
      # @param error [IO] An `IO`-like object to write error lines to.
      def initialize(processor, input = $stdin, output = $stdout, error = $stderr)
        if processor.version == 1
          @processor = Aws::KCLrb::V2::V2ToV1Adapter.new(processor)
        else
          @processor = processor
        end
        @io_proxy = IOProxy.new(input, output, error)
        @checkpointer = CheckpointerImpl.new(@io_proxy)
      end

      # Starts this KCL processor's main loop.
      def run
        action = @io_proxy.read_action
        while action do
          process_action(action)
          action = @io_proxy.read_action
        end
      end

      private

      # @api private
      # Parses an input action and invokes the appropriate method of the
      # record processor.
      #
      # @param action [Hash] A hash that represents an action to take with
      #   appropriate attributes, as retrieved from {IOProxy#read_action}, e.g.
      #
      #   - `{"action":"initialize","shardId":"shardId-123"}`
      #   - `{"action":"processRecords","records":[{"data":"bWVvdw==","partitionKey":"cat","sequenceNumber":"456"}]}`
      #   - `{"action":"shutdown","reason":"TERMINATE"}`
      # @raise [MalformedAction] if the action is missing expected attributes.
      def process_action(action)
        action_name = action.fetch('action')
        case action_name
        when 'initialize'
          dispatch_to_processor(:init_processor,
                                Aws::KCLrb::V2::InitializeInput.new(action.fetch('shardId'),
                                                                    action.fetch('sequenceNumber')))
        when 'processRecords'
          dispatch_to_processor(:process_records,
                                Aws::KCLrb::V2::ProcessRecordsInput.new(action.fetch('records'),
                                                                        action.fetch('millisBehindLatest'),
                                                                        @checkpointer))
        when 'leaseLost'
          dispatch_to_processor(:lease_lost, Aws::KCLrb::V2::LeaseLostInput.new)
        when 'shardEnded'
          dispatch_to_processor(:shard_ended, Aws::KCLrb::V2::ShardEndedInput.new(@checkpointer))
        when 'shutdownRequested'
          dispatch_to_processor(:shutdown_requested, Aws::KCLrb::V2::ShutdownRequestedInput.new(@checkpointer))
        else
          raise MalformedAction.new("Received an action which couldn't be understood. Action was '#{action}'")
        end
        @io_proxy.write_action('status', {'responseFor' => action_name})
      rescue KeyError => ke
        raise MalformedAction.new("Action '#{action}': #{ke.message}")
      end

      # @api private
      # Calls the specified method on the record processor, and handles
      # any resulting exceptions by writing to the error stream.
      def dispatch_to_processor(method, *args)
        @processor.send(method, *args)
      rescue => processor_error
        # We don't know what the client's code could raise and we have
        #   no way to recover if we let it propagate up further. We will
        #   mimic the KCL and pass over client errors. We print their
        #   stack trace to STDERR to help them notice and debug this type
        #   of issue.
        @io_proxy.write_error(processor_error)
      end

    end
  end
end
