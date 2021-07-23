gem_version = File.read(File.join(File.dirname(__FILE__), 'RUNNER_VERSION')).strip
Gem::Specification.new do |spec|
  spec.name        = 'aws-kcl-runner'
  spec.version     = gem_version
  spec.summary     = 'Amazon Kinesis Client Library .jar file installer'
  spec.description = 'A ruby interface for installing the Amazon Kinesis Client Library MultiLangDaemon'
  spec.author      = 'Amazon Web Services'
  spec.files       = ['Rakefile', 'LICENSE.txt', 'RUNNER_VERSION']
  spec.licenses    = ['Apache-2.0']
  spec.platform    = Gem::Platform::RUBY
  spec.homepage    = 'http://github.com/Grayscale-Labs/amazon-kinesis-client-ruby'
end
