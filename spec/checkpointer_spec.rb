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

require 'aws/kclrb/io_proxy.rb'
require 'aws/kclrb/checkpointer.rb'

module Aws::KCLrb
  describe Checkpointer do
    describe "#checkpoint" do
      it "should emit a checkpoint action and consume response action" do
        seq_number = rand(100_000).to_s
        expected_output_string = %Q[{"action":"checkpoint","checkpoint":"#{seq_number}"}]
        input_string = %Q[{"action":"checkpoint","checkpoint":"#{seq_number}"}]
        input = StringIO.new(input_string)
        output = StringIO.new
        error = StringIO.new
        io_proxy = IOProxy.new(input, output, error)
        checkpointer = CheckpointerImpl.new(io_proxy)
        checkpointer.checkpoint(seq_number)
        expect( output.string.strip ).to eq(expected_output_string.strip)
        expect( input.eof? ).to eq(true)
      end

      it "should raise a CheckpointError when error is received from MultiLangDaemon" do
        seq_number = rand(100_000).to_s
        expected_output_string = %Q[{"action":"checkpoint","checkpoint":"#{seq_number}"}]
        input_string = %Q[{"action":"checkpoint","checkpoint":"#{seq_number}","error":"ThrottlingException"}]
        input = StringIO.new(input_string)
        output = StringIO.new
        error = StringIO.new
        io_proxy = IOProxy.new(input, output, error)
        checkpointer = CheckpointerImpl.new(io_proxy)
        expect { checkpointer.checkpoint(seq_number) }.to raise_error(CheckpointError, /ThrottlingException/)
        expect( output.string.strip ).to eq(expected_output_string.strip)
        expect( input.eof? ).to eq(true)
      end
    end
  end
end
