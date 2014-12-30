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

require 'aws/kclrb/io_proxy'
require 'aws/kclrb/checkpointer'

module Aws
  module KCLrb
    # Error raised if the {KCLProcess} received an input action that it
    # could not parse or it could not handle.
    class MalformedAction < RuntimeError; end
  
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
      def initialize(processor, input=$stdin, output=$stdout, error=$stderr)
        @processor = processor
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
          dispatch_to_processor(:init_processor, action.fetch('shardId'))
        when 'processRecords'
          dispatch_to_processor(:process_records, action.fetch('records'), @checkpointer)
        when 'shutdown'
          dispatch_to_processor(:shutdown, @checkpointer, action.fetch('reason'))
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
