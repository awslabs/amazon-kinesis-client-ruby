# Amazon Kinesis Client Library for Ruby

This package provides an interface to the Amazon Kinesis Client Library's (KCL) [MultiLangDaemon][multi-lang-daemon]
for the Ruby language.
Developers can use the [Amazon KCL][amazon-kcl] to build distributed applications that process streaming data reliably
at scale. The [Amazon KCL][amazon-kcl] takes care of many of the complex tasks associated with distributed computing,
such as load-balancing across multiple instances, responding to instance failures, checkpointing processed records,
and reacting to changes in stream volume.
This package wraps and manages the interaction with the [MultiLangDaemon][multi-lang-daemon] which is part of the
[Amazon KCL for Java][amazon-kcl-github] so that developers can focus on implementing their record processor
executable. A record processor in Ruby typically looks something like:

```ruby
#! /usr/bin/env ruby

require 'aws/kclrb'

class SampleRecordProcessor < Aws::KCLrb::V2::RecordProcessorBase
  def init_processor(initialize_input)
    # initialize
  end

  def process_records(process_records_input)
    # process batch of records
  end

  def lease_lost(lease_lost_input)
    # lease was lost, cleanup
  end

  def shard_ended(shard_ended_input)
    # shard has ended, cleanup
  end

  def shutdown_requested(shutdown_requested_input)
    # shutdown has been requested
  end
end

if __FILE__ == $0
  # Start the main processing loop
  record_processor = SampleRecordProcessor.new
  driver = Aws::KCLrb::KCLProcess.new(record_processor)
  driver.run
end
```

## Before You Get Started

Before running the samples, you'll want to make sure that your environment is
configured to allow the samples to use your
[AWS Security Credentials](http://docs.aws.amazon.com/general/latest/gr/aws-security-credentials.html).

By default the samples use the [DefaultCredentialsProvider][DefaultCredentialsProvider]
so you'll want to make your credentials available to one of the credentials providers in that
provider chain. There are several ways to do this such as providing a `~/.aws/credentials` file,
or if you're running on Amazon EC2, you can associate an IAM role with your instance with appropriate
access.

For questions regarding [Amazon Kinesis Service][amazon-kinesis] and the client libraries please check the
[official documentation][amazon-kinesis-docs] as well as the [Amazon Kinesis Forums][kinesis-forum].

## Running the Sample

Using the Amazon KCL for Ruby package requires the [MultiLangDaemon][multi-lang-daemon] which
is provided by the [Amazon KCL for Java][amazon-kcl-github]. Rake tasks are provided to start the sample
application(s) and download all the required dependencies.

The sample application consists of two components:

* A data producer (`samples/sample_kcl_producer.rb`): this script creates an Amazon Kinesis
  stream and starts putting random records into it.
* A data processor (`samples/sample_kcl.rb`): this script is invoked by the
  [MultiLangDaemon][multi-lang-daemon] and consumes the data from the Amazon Kinesis
  stream and stores it into files (1 file per shard).

The following defaults are used in the sample application:

* *Stream name*: `kclrbsample`
* *Region*: `us-east-1`
* *Number of shards*: 2
* *Amazon KCL application name*: `RubyKCLSample`
* *Amazon DynamoDB table for KCL application*: `RubyKCLSample`
* *Amazon CloudWatch metrics namespace for KCL application*: `RubyKCLSample`

### Running the Data Producer

To run the data producer indefinitely, run the following commands:

```sh
    cd samples
    rake run_producer
```

To run the data producer with a timeout, run the following commands:

```sh
    cd samples
    rake "run_producer[t]"
```
* *note: replace t with number of seconds to run the producer*

#### Notes

* The [AWS Ruby SDK gem][aws-ruby-sdk-gem] for Kinesis needs to be installed as a pre-requisite. To install,
  run:

  ```sh
      sudo gem install aws-sdk-kinesis
  ```

* The script `samples/sample_kcl_producer.rb` takes several parameters that you can use
  to customize its behavior. To see the available options, run:

  ```sh
      samples/sample_kcl_producer.rb --help
  ```

### Running the Data Processor

To run the data processor, run the following commands:

```sh
    cd samples
    rake run properties_file=sample.properties
```

#### Notes

* The `JAVA_HOME` environment variable needs to point to a valid JVM.
* The rake task invokes the [MultiLangDaemon][multi-lang-daemon] passing to it the
  properties file `samples/sample.properties`. This file contains the
  information needed to bootstrap the sample application, e.g.

  * `executableName = samples/sample_kcl.rb`
  * `streamName = kclrbsample`
  * `applicationName = RubyKCLSample`
  * `regionName = us-east-1`

### Cleaning Up

This sample application creates a real Amazon Kinesis stream and sends real data to it, and
create a real DynamoDB table to track the Amazon KCL application state, thus potentially
incurring AWS costs. Once done, you can log in to AWS management console and delete these
resources. Specifically, the sample application will create in your default AWS region

* an *Amazon Kinesis Data Stream* named `kclrbsample`
* an *Amazon DynamoDB table* named `RubyKCLSample`

## Running on Amazon EC2

Running on Amazon EC2 is simple. Assuming you are already logged into an Amazon EC2
instance running Amazon Linux, the following steps will prepare your environment
for running the sample application. Note the version of Java that ships with
Amazon Linux can be found at `/usr/bin/java` and should be 1.7 or greater.

```sh
    # install some prerequisites if missing
    sudo yum install gcc patch git ruby rake rubygems ruby-devel
    # install the AWS Ruby SDK (pre-requisuite for producer)
    sudo gem install aws-sdk aws-kclrb
    # clone the git repository to work with the samples
    git clone https://github.com/awslabs/amazon-kinesis-client-ruby.git kclrb
    # run the sample
    cd kclrb/samples
    rake run_producer
    # ... and in another terminal
    rake run properties_file=sample.properties
```

## Under the Hood - What You Should Know about Amazon KCL's [MultiLangDaemon][multi-lang-daemon]

Amazon KCL for Ruby uses [Amazon KCL for Java][amazon-kcl-github] internally. We have implemented
a Java-based daemon, called the *MultiLangDaemon* that does all the heavy lifting. Our approach
has the daemon spawn the user-defined record processor script/program as a sub-process. The
*MultiLangDaemon* communicates with this sub-process over standard input/output using a simple
protocol, and therefore the record processor script/program can be written in any language.

At runtime, there will always be a one-to-one correspondence between a record processor, a child process,
and an [Amazon Kinesis Shard][amazon-kinesis-shard]. The *MultiLangDaemon* will make sure of
that, without any need for the developer to intervene.

In this release, we have abstracted these implementation details away and exposed an interface that enables
you to focus on writing record processing logic in Ruby. This approach enables [Amazon KCL][amazon-kcl] to
be language agnostic, while providing identical features and similar parallel processing model across
all languages.

## See Also

* [Developing Consumer Applications for Amazon Kinesis Using the Amazon Kinesis Client Library][amazon-kcl]
* The [Amazon KCL for Java][amazon-kcl-github]
* The [Amazon KCL for Python][amazon-kinesis-python-github]
* The [Amazon Kinesis Documentation][amazon-kinesis-docs]
* The [Amazon Kinesis Forum][kinesis-forum]

## Release Notes
### Release 3.1.1 (October 29, 2025)
* [#121](https://github.com/awslabs/amazon-kinesis-client-ruby/pull/121) Upgrade netty.version from 4.2.4.Final to 4.2.7.Final

### Release 3.1.0 (October 1, 2025)
* [#108](https://github.com/awslabs/amazon-kinesis-client-ruby/pull/108) Add multi-lang support for leaseAssignmentIntervalMillis
* [#116](https://github.com/awslabs/amazon-kinesis-client-ruby/pull/116) Upgrade amazon-kinesis-client from 3.0.0 to 3.1.3
* [#116](https://github.com/awslabs/amazon-kinesis-client-ruby/pull/116) Upgrade aws-sdk from 2.25.64 to 2.33.0
* [#116](https://github.com/awslabs/amazon-kinesis-client-ruby/pull/116) Upgrade netty.version from 4.1.108.Final to 4.2.4.Final
* [#116](https://github.com/awslabs/amazon-kinesis-client-ruby/pull/116) Upgrade fasterxml-jackson from 2.13.5 to 2.15.0
* [#116](https://github.com/awslabs/amazon-kinesis-client-ruby/pull/116) Upgrade checker-qual from 2.5.2 to 3.49.4
* [#116](https://github.com/awslabs/amazon-kinesis-client-ruby/pull/116) Upgrade org.apache.commons:commons-lang3 from 3.14.0 to 3.18.0
* [#93](https://github.com/awslabs/amazon-kinesis-client-ruby/pull/93) Upgrade logback.version from 1.3.14 to 1.13.15
* [#96](https://github.com/awslabs/amazon-kinesis-client-ruby/pull/96) Upgrade commons-beanutils from 1.9.4 to 1.11.0

### Release 3.0.0 (November 6, 2024)
* New lease assignment / load balancing algorithm
  * KCL 3.x introduces a new lease assignment and load balancing algorithm. It assigns leases among workers based on worker utilization metrics and throughput on each lease, replacing the previous lease count-based lease assignment algorithm.
  * When KCL detects higher variance in CPU utilization among workers, it proactively reassigns leases from over-utilized workers to under-utilized workers for even load balancing. This ensures even CPU utilization across workers and removes the need to over-provision the stream processing compute hosts.
* Optimized DynamoDB RCU usage
  * KCL 3.x optimizes DynamoDB read capacity unit (RCU) usage on the lease table by implementing a global secondary index with leaseOwner as the partition key. This index mirrors the leaseKey attribute from the base lease table, allowing workers to efficiently discover their assigned leases by querying the index instead of scanning the entire table.
  * This approach significantly reduces read operations compared to earlier KCL versions, where workers performed full table scans, resulting in higher RCU consumption.
* Graceful lease handoff
  * KCL 3.x introduces a feature called "graceful lease handoff" to minimize data reprocessing during lease reassignments. Graceful lease handoff allows the current worker to complete checkpointing of processed records before transferring the lease to another worker. For graceful lease handoff, you should implement checkpointing logic within the existing `shutdownRequested()` method.
  * This feature is enabled by default in KCL 3.x, but you can turn off this feature by adjusting the configuration property `isGracefulLeaseHandoffEnabled`.
  * While this approach significantly reduces the probability of data reprocessing during lease transfers, it doesn't completely eliminate the possibility. To maintain data integrity and consistency, it's crucial to design your downstream consumer applications to be idempotent. This ensures that the application can handle potential duplicate record processing without adverse effects.
* New DynamoDB metadata management artifacts
  * KCL 3.x introduces two new DynamoDB tables for improved lease management:
    * Worker metrics table: Records CPU utilization metrics from each worker. KCL uses these metrics for optimal lease assignments, balancing resource utilization across workers. If CPU utilization metric is not available, KCL assigns leases to balance the total sum of shard throughput per worker instead.
    * Coordinator state table: Stores internal state information for workers. Used to coordinate in-place migration from KCL 2.x to KCL 3.x and leader election among workers.
  * Follow this [documentation](https://docs.aws.amazon.com/streams/latest/dev/kcl-migration-from-2-3.html#kcl-migration-from-2-3-IAM-permissions) to add required IAM permissions for your KCL application.
* Other improvements and changes
  * Dependency on the AWS SDK for Java 1.x has been fully removed.
    * The Glue Schema Registry integration functionality no longer depends on AWS SDK for Java 1.x. Previously, it required this as a transient dependency.
    * Multilangdaemon has been upgraded to use AWS SDK for Java 2.x. It no longer depends on AWS SDK for Java 1.x.
  * `idleTimeBetweenReadsInMillis` (PollingConfig) now has a minimum default value of 200.
    * This polling configuration property determines the [publishers](https://github.com/awslabs/amazon-kinesis-client/blob/master/amazon-kinesis-client/src/main/java/software/amazon/kinesis/retrieval/polling/PrefetchRecordsPublisher.java) wait time between GetRecords calls in both success and failure cases. Previously, setting this value below 200 caused unnecessary throttling. This is because Amazon Kinesis Data Streams supports up to five read transactions per second per shard for shared-throughput consumers.
  * Shard lifecycle management is improved to deal with edge cases around shard splits and merges to ensure records continue being processed as expected.
* Migration
  * The programming interfaces of KCL 3.x remain identical with KCL 2.x for an easier migration. For detailed migration instructions, please refer to the [Migrate consumers from KCL 2.x to KCL 3.x](https://docs.aws.amazon.com/streams/latest/dev/kcl-migration-from-2-3.html) page in the Amazon Kinesis Data Streams developer guide.
* Configuration properties
  * New configuration properties introduced in KCL 3.x are listed in this [doc](https://github.com/awslabs/amazon-kinesis-client/blob/master/docs/kcl-configurations.md#new-configurations-in-kcl-3x).
  * Deprecated configuration properties in KCL 3.x are listed in this [doc](https://github.com/awslabs/amazon-kinesis-client/blob/master/docs/kcl-configurations.md#discontinued-configuration-properties-in-kcl-3x). You need to keep the deprecated configuration properties during the migration from any previous KCL version to KCL 3.x.
* Metrics
  * New CloudWatch metrics introduced in KCL 3.x are explained in the [Monitor the Kinesis Client Library with Amazon CloudWatch](https://docs.aws.amazon.com/streams/latest/dev/monitoring-with-kcl.html) in the Amazon Kinesis Data Streams developer guide. The following operations are newly added in KCL 3.x:
    * `LeaseAssignmentManager`
    * `WorkerMetricStatsReporter`
    * `LeaseDiscovery`

### Release 2.1.1 (February 21, 2023)
* [#69](https://github.com/awslabs/amazon-kinesis-client-ruby/pull/69) Include `pom.xml` in the gemspec

### Release 2.1.0 (January 12, 2023)
* Upgraded to use version 2.4.4 of the [Amazon Kinesis Client library][amazon-kcl-github]

### Release 2.0.0 (February 26, 2019)
* Added support for [Enhanced Fan-Out](https://aws.amazon.com/blogs/aws/kds-enhanced-fanout/).  
  Enhanced Fan-Out provides dedicated throughput per stream consumer, and uses an HTTP/2 push API (SubscribeToShard) to deliver records with lower latency.
* Updated the Amazon Kinesis Client Library for Java to version 2.1.2.
  * Version 2.1.2 uses 4 additional Kinesis API's  
    __WARNING: These additional API's may require updating any explicit IAM policies__
    * [`RegisterStreamConsumer`](https://docs.aws.amazon.com/kinesis/latest/APIReference/API_RegisterStreamConsumer.html)
    * [`SubscribeToShard`](https://docs.aws.amazon.com/kinesis/latest/APIReference/API_SubscribeToShard.html)
    * [`DescribeStreamConsumer`](https://docs.aws.amazon.com/kinesis/latest/APIReference/API_DescribeStreamConsumer.html)
    * [`DescribeStreamSummary`](https://docs.aws.amazon.com/kinesis/latest/APIReference/API_DescribeStreamSummary.html)
  * For more information about Enhanced Fan-Out with the Amazon Kinesis Client Library please see the [announcement](https://aws.amazon.com/blogs/aws/kds-enhanced-fanout/) and [developer documentation](https://docs.aws.amazon.com/streams/latest/dev/introduction-to-enhanced-consumers.html).
* Added version 2 of the [`RecordProcessorBase`](https://github.com/awslabs/amazon-kinesis-client-ruby/blob/d5c2bbafb232b5e1ab947980a0bd8505c87978f9/lib/aws/kclrb/record_processor.rb#L102) which supports the new `ShardRecordProcessor` interface
  * The `shutdown` method from version 1 has been replaced by `lease_lost` and `shard_ended`.
  * Added the `lease_lost` method which is invoked when a lease is lost.  
    `lease_lost` replaces `shutdown(checkpointer, 'ZOMBIE')`.
  * Added the `shard_ended` method which is invoked when all records from a split or merge have been processed.  
    `shard_ended` replaces `shutdown(checkpointer, 'TERMINATE')`.
  * Added an optional method, `shutdown_requested`, which provides the record processor a last chance to checkpoint during the Amazon Kinesis Client Library shutdown process before the lease is canceled.  
    * To control how long the Amazon Kinesis Client Library waits for the record processors to complete shutdown, add `timeoutInSeconds=<seconds to wait>` to your properties file.
* Updated the AWS Java SDK version to 2.4.0
* MultiLangDaemon now provides logging using Logback.
  * MultiLangDaemon supports custom configurations for logging via a Logback XML configuration file.
  * The example [Rakefile](https://github.com/awslabs/amazon-kinesis-client-ruby/blob/master/samples/Rakefile) supports setting the logging configuration by adding `log_configuration=<log configuration file>` to the Rake command line.

### Release 1.0.1 (January 19, 2017)
* Upgraded to use version 1.7.2 of the [Amazon Kinesis Client library][amazon-kcl-github]

### Release 1.0.0 (December 30, 2014)
* **aws-kclrb** gem which exposes an interface to allow implementation of record processors in Ruby
  using the Amazon KCL's [MultiLangDaemon][multi-lang-daemon]
* **samples** directory contains a sample producer and processing applications using the Amazon KCL
  for Ruby library.

[amazon-kinesis]: http://aws.amazon.com/kinesis
[amazon-kinesis-docs]: http://aws.amazon.com/documentation/kinesis/
[amazon-kinesis-shard]: http://docs.aws.amazon.com/kinesis/latest/dev/key-concepts.html
[amazon-kcl]: http://docs.aws.amazon.com/kinesis/latest/dev/kinesis-record-processor-app.html
[amazon-kcl-github]: https://github.com/awslabs/amazon-kinesis-client
[amazon-kinesis-python-github]: https://github.com/awslabs/amazon-kinesis-client-python
[multi-lang-daemon]: https://github.com/awslabs/amazon-kinesis-client/blob/master/amazon-kinesis-client-multilang/src/main/java/software/amazon/kinesis/multilang/package-info.java
[DefaultCredentialsProvider]: https://sdk.amazonaws.com/java/api/latest/software/amazon/awssdk/auth/credentials/DefaultCredentialsProvider.html
[kinesis-forum]: http://developer.amazonwebservices.com/connect/forum.jspa?forumID=169
[aws-ruby-sdk-gem]: https://rubygems.org/gems/aws-sdk

## License

This library is licensed under the Apache 2.0 License.
