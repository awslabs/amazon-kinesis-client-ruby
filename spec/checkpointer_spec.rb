#
#  Copyright 2014 Amazon.com, Inc. or its affiliates. All Rights Reserved.
#  SPDX-License-Identifier: Apache-2.0

require 'aws/kclrb/io_proxy.rb'
require 'aws/kclrb/checkpointer.rb'

module Aws::KCLrb
  describe Checkpointer do
    describe "#checkpoint" do
      it "should emit a checkpoint action and consume response action" do
        seq_number = rand(100_000).to_s
        expected_output_string = %Q[{"action":"checkpoint","sequenceNumber":"#{seq_number}"}]
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
        expected_output_string = %Q[{"action":"checkpoint","sequenceNumber":"#{seq_number}"}]
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
