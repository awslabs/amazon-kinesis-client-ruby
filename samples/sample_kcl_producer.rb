#! /usr/bin/env ruby
#
#  Copyright 2014 Amazon.com, Inc. or its affiliates. All Rights Reserved.
#  SPDX-License-Identifier: Apache-2.0

require 'aws-sdk-core'
require 'aws-sdk-kinesis'
require 'multi_json'
require 'optparse'

# @api private
class SampleProducer
  def initialize(service, stream_name, sleep_between_puts, shard_count=nil)
    @stream_name = stream_name
    @shard_count = shard_count
    @sleep_between_puts = sleep_between_puts
    @kinesis = service
  end

  def run(timeout=0)
    create_stream_if_not_exists
    start = Time.now
    while (timeout == 0 || (Time.now - start) < timeout)
      put_record
      sleep @sleep_between_puts
    end
  end

  def delete_stream_if_exists
    begin
      @kinesis.delete_stream(:stream_name => @stream_name)
      puts "Deleted stream #{@stream_name}"
    rescue Aws::Kinesis::Errors::ResourceNotFoundException
      # nothing to do
    end
  end

  def create_stream_if_not_exists
    begin
      desc = get_stream_description
      if desc[:stream_status] == 'DELETING'
        fail "Stream #{@stream_name} is being deleted. Please re-run the script."
      elsif desc[:stream_status] != 'ACTIVE'
        wait_for_stream_to_become_active
      end
      if @shard_count && desc[:shards].size != @shard_count
        fail "Stream #{@stream_name} has #{desc[:shards].size} shards, while requested number of shards is #{@shard_count}"
      end
      puts "Stream #{@stream_name} already exists with #{desc[:shards].size} shards"
    rescue Aws::Kinesis::Errors::ResourceNotFoundException
      puts "Creating stream #{@stream_name} with #{@shard_count || 2} shards"
      @kinesis.create_stream(:stream_name => @stream_name,
                             :shard_count => @shard_count || 2)
      wait_for_stream_to_become_active
    end
  end

  def put_record
    data = get_data
    data_blob = MultiJson.dump(data)
    r = @kinesis.put_record(:stream_name => @stream_name,
                            :data => data_blob,
                            :partition_key => data["sensor"])
    puts "Put record to shard '#{r[:shard_id]}' (#{r[:sequence_number]}): '#{MultiJson.dump(data)}'"
  end

  private
  def get_data
    {
       "time"=>"#{Time.now.to_f}",
       "sensor"=>"snsr-#{rand(1_000).to_s.rjust(4,'0')}",
       "reading"=>"#{rand(1_000_000)}"
    }
  end

  def get_stream_description
    r = @kinesis.describe_stream(:stream_name => @stream_name)
    r[:stream_description]
  end

  def wait_for_stream_to_become_active
    sleep_time_seconds = 3
    status = get_stream_description[:stream_status]
    while status && status != 'ACTIVE' do
      puts "#{@stream_name} has status: #{status}, sleeping for #{sleep_time_seconds} seconds"
      sleep(sleep_time_seconds)
      status = get_stream_description[:stream_status]
    end
  end
end

if __FILE__ == $0
  aws_region = nil
  stream_name = 'kclrbsample'
  shard_count = nil
  sleep_between_puts = 0.25
  timeout = 0
  # Get and parse options
  option_parser = OptionParser.new do |opts|
    opts.banner = "Usage: #{File.basename($0)} [options]"
    opts.on("-s STREAM_NAME", "--stream STREAM_NAME", "Name of the stream to use. Will be created if it doesn't exist. (Default: '#{stream_name}')") do |s|
      stream_name = s
    end
    opts.on("-d SHARD_COUNT", "--shards SHARD_COUNT", "Number of shards to use when creating the stream. (Default: 2)") do |s|
      shard_count = s.to_i
    end
    opts.on("-r REGION_NAME", "--region REGION_NAME", "AWS region name (see http://tinyurl.com/cc9cap7). (Default: SDK default)") do |r|
      aws_region = r
    end
    opts.on("-p SLEEP_SECONDS", "--sleep SLEEP_SECONDS", Float, "How long to sleep betweep puts (seconds, can be fractional). (Default #{sleep_between_puts})") do |s|
      sleep_between_puts = s.to_f
      raise OptionParser::ParseError.new("SLEEP_SECONDS must be a non-negative number")  unless sleep_between_puts >= 0.0
    end
    opts.on("-t TIMEOUT_SECONDS", "--timeout TIMEOUT_SECONDS", Float, "How long to keep running. By default producer keeps running indefinitely. (Default: #{timeout})") do |t|
      timeout = t.to_f
      raise OptionParser::ParseError.new("TIMEOUT_SECONDS must be a non-negative number")  unless timeout >= 0.0
    end
    opts.on("-h", "--help", "Prints this help message.") do
      puts opts
      exit
    end
  end
  begin
    option_parser.parse!
    raise OptionParser::ParseError.new("STREAM_NAME is required")  if !stream_name || stream_name.strip.empty?
  rescue
    $stderr.puts option_parser
    raise
  end

  # Getting a connection to Amazon Kinesis will require that you have
  # your credentials available to one of the standard credentials providers.
  # See http://docs.aws.amazon.com/AWSJavaSDK/latest/javadoc/com/amazonaws/auth/DefaultAWSCredentialsProviderChain.html
  kconfig = {}
  kconfig[:region] = aws_region  if aws_region
  kinesis = Aws::Kinesis::Client.new(kconfig)

  producer = SampleProducer.new(kinesis, stream_name, sleep_between_puts, shard_count)
  producer.run(timeout)
end
