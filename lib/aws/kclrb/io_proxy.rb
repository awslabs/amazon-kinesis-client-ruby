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
#

require 'multi_json'

module Aws
  module KCLrb
    # @api private
    # Internal class used by {KCLProcess} and {Checkpointer} to communicate 
    # with the the {https://github.com/awslabs/amazon-kinesis-client/blob/master/src/main/java/com/amazonaws/services/kinesis/multilang/package-info.java MultiLangDaemon} via the input and output streams.
    class IOProxy
      # @param input [IO, #readline] An `IO`-like object to read input lines from (e.g. `$stdin`).
      # @param output [IO] An `IO`-like object to write output lines to (e.g. `$stdout`).
      # @param error [IO] An `IO`-like object to write error lines to (e.g. `$stderr`).
      def initialize(input, output, error)
        @input = input
        @output = output
        @error = error
      end
  
      # Reads one line from the input IO, strips it from any
      # leading/trailing whitespaces, skipping empty lines.
      #
      # @return [String, nil] The line read from the input IO or `nil`
      #   if end of stream was reached.
      def read_line
        line = nil
        begin
          line = @input.readline
          break  unless line
          line.strip!
        end while line.empty?
        line
      rescue EOFError
        nil
      end
  
      # Reads a line and decodes it as a message from the {https://github.com/awslabs/amazon-kinesis-client/blob/master/src/main/java/com/amazonaws/services/kinesis/multilang/package-info.java MultiLangDaemon}.
      #
      # @return [Hash]  A hash representing the contents of the line, e.g. 
      #   `{"action" => "initialize", "shardId" => "shardId-000001"}`
      def read_action
        line = read_line
        if line
          MultiJson.load(line)
        end
      end
  
      # Writes a line to the output stream. The line is preceded and followed by a 
      # new line because other libraries could be writing to the output stream as 
      # well (e.g. some libs might write debugging info to `$stdout`) so we would
      # like to prevent our lines from being interlaced with other messages so 
      # the MultiLangDaemon can understand them.
      #
      # @param line [String] A line to write to the output stream, e.g. 
      #   `{"action":"status","responseFor":"<someAction>"}`
      def write_line(line)
        @output.write("\n#{line}\n")
        @output.flush
      end
  
  
      # Writes a line to the error file.
      #
      # @param error [String,Exception] An exception or error message
      def write_error(error)
        if error.is_a?(Exception)
          error = "#{error.class}: #{error.message}\n\t#{error.backtrace.join("\n\t")}"
        end
        @error.write("#{error}\n")
        @error.flush
      end
  
      # Writes a response action to the {https://github.com/awslabs/amazon-kinesis-client/blob/master/src/main/java/com/amazonaws/services/kinesis/multilang/package-info.java MultiLangDaemon},
      # in JSON of the form:
      #   `{"action":"<action>","detail1":"value1",...}`
      # where the details depend on the type of the action. See {https://github.com/awslabs/amazon-kinesis-client/blob/master/src/main/java/com/amazonaws/services/kinesis/multilang/package-info.java MultiLangDaemon documentation} for more infortmation.
      #
      # @param action [String] The action name that will be put into the output JSON's `action` attribute.
      # @param details [Hash] Additional key-value pairs to be added to the action response.
      def write_action(action, details={})
        response = {'action' => action}.merge(details)
        write_line(MultiJson.dump(response))
      end
    end
  end
end