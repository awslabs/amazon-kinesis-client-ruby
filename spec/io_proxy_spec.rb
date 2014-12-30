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

module Aws::KCLrb
  describe IOProxy do
    describe "#read_line" do
      it "should skip blank lines" do
        input_string = "    \nline1\n\n\n  \nline2\n   \n"
        input = StringIO.new(input_string)
        output = StringIO.new
        error = StringIO.new
        io_proxy = IOProxy.new(input, output, error)
        expect( io_proxy.read_line ).to eq("line1")
        expect( io_proxy.read_line ).to eq("line2")
        expect( io_proxy.read_line ).to be_nil
      end
      it "should return nil on EOF" do
        input_string = "line1\n"
        input = StringIO.new(input_string)
        output = StringIO.new
        error = StringIO.new
        io_proxy = IOProxy.new(input, output, error)
        expect( io_proxy.read_line ).to eq("line1")
        expect( io_proxy.read_line ).to be_nil
        expect( io_proxy.read_line ).to be_nil
      end
    end
    describe "#write_error" do
      it "should write an error message to the error stream" do
        input = StringIO.new
        output = StringIO.new
        error = StringIO.new
        io_proxy = IOProxy.new(input, output, error)
        io_proxy.write_error('an error message')
        expect( error.string.strip ).to eq('an error message')
      end
      it "should write exception details to the error stream" do
        input = StringIO.new
        output = StringIO.new
        error = StringIO.new
        io_proxy = IOProxy.new(input, output, error)
        begin
          raise RuntimeError.new("Test error")
        rescue => e
          io_proxy.write_error(e)
        end
        #puts error.string
        expect( error.string.strip ).to match(/RuntimeError.*Test error/)
      end
    end
    describe "#write_action" do
      it "should write a valid JSON action to the output stream" do
        input = StringIO.new
        output = StringIO.new
        error = StringIO.new
        io_proxy = IOProxy.new(input, output, error)
        io_proxy.write_action('status', 'responseFor' => 'initialize')
        expect( output.string.strip ).to eq('{"action":"status","responseFor":"initialize"}')
      end
    end
  end
end
