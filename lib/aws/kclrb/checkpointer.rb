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

module Aws
  module KCLrb
    # Error class used for wrapping exception names passed through the 
    # input stream.
    class CheckpointError < RuntimeError
      # @!attribute [r] value
      # @return [String] the name of the exception wrapped by this instance.
      attr_reader :value
  
      # @param value [String] The name of the exception that was received 
      #   while checkpointing. For more details see 
      #   {https://github.com/awslabs/amazon-kinesis-client/tree/master/src/main/java/com/amazonaws/services/kinesis/clientlibrary/exceptions KCL exceptions}.
      #   Any of these exception names could be returned by the {https://github.com/awslabs/amazon-kinesis-client/blob/master/src/main/java/com/amazonaws/services/kinesis/multilang/package-info.java MultiLangDaemon}
      #   as a response to a checkpoint action.
      def initialize(value)
        @value = value
      end
  
      # @return [String] the name of the wrapped exception.
      def to_s
        @value.to_s
      end
    end
  
    # @abstract
    # A checkpointer class which allows you to make checkpoint requests.
    # 
    # A checkpoint marks a point in a shard where you've successfully 
    # processed to. If this processor fails or loses its lease to that 
    # shard, another processor will be started either by this 
    # {https://github.com/awslabs/amazon-kinesis-client/blob/master/src/main/java/com/amazonaws/services/kinesis/multilang/package-info.java MultiLangDaemon} 
    # or a different instance and resume at the most recent checkpoint 
    # in this shard.
    class Checkpointer
  
      # Checkpoints at a particular sequence number you provide or if `nil`
      # was passed, the checkpoint will be at the end of the most recently
      # delivered list of records.      
      #
      # @param sequence_number [String, nil] The sequence number to checkpoint at 
      #   or `nil` if you want to checkpoint at the farthest record.
      # @raise [CheckpointError] if the {https://github.com/awslabs/amazon-kinesis-client/blob/master/src/main/java/com/amazonaws/services/kinesis/multilang/package-info.java MultiLangDaemon}
      #   returned a response indicating an error, or if the checkpointer
      #   encountered unexpected input.
      def checkpoint(sequence_number=nil)
        fail NotImplementedError.new
      end
    end
    
    
    # @api private
    # Default implementation of the {Checkpointer} abstract class.
    class CheckpointerImpl
      # @param io_proxy [IOProxy]  An {IOProxy} object to be used to read/write
      #   checkpoint actions from/to the {https://github.com/awslabs/amazon-kinesis-client/blob/master/src/main/java/com/amazonaws/services/kinesis/multilang/package-info.java MultiLangDaemon}.
      def initialize(io_proxy)
        @io_proxy = io_proxy
      end
  
      # (see Checkpointer#checkpoint)
      def checkpoint(sequence_number=nil)
        @io_proxy.write_action('checkpoint', 'checkpoint' => sequence_number)
        # Consume the response action
        action = @io_proxy.read_action
        # Happy response is expected to be of the form:
        #   `{"action":"checkpoint","checkpoint":"<seq-number>"}`
        # Error response would look like the following:
        #   `{"action":"checkpoint","checkpoint":"<seq-number>","error":"<error-type>"}`
        if action && action['action'] == 'checkpoint'
          raise CheckpointError.new(action['error'])  if action['error']
        else
          # We are in an invalid state. We will raise a checkpoint exception
          #  to the RecordProcessor indicating that the KCL (or KCLrb) is in
          #  an invalid state. See KCL documentation for description of this
          #  exception. Note that the documented guidance is that this exception
          #  is NOT retriable so the client code should exit (see 
          #  https://github.com/awslabs/amazon-kinesis-client/tree/master/src/main/java/com/amazonaws/services/kinesis/clientlibrary/exceptions)
          raise CheckpointError.new('InvalidStateException')
        end
      end
    end
  end
end
