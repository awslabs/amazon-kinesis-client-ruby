gem_version = File.read(File.join(File.dirname(__FILE__), 'VERSION')).strip
Gem::Specification.new do |spec|
  spec.name            = 'aws-kclrb'
  spec.version         = gem_version
  spec.summary         = 'Amazon Kinesis Client Library for Ruby'
  spec.description     = 'A ruby interface for the Amazon Kinesis Client Library MultiLangDaemon'
  spec.author          = 'Amazon Web Services'
  spec.files           = Dir['lib/**/*.rb'] 
  spec.files          += Dir['spec/**/*.rb']
  spec.files          += ['README.md', 'LICENSE.txt', 'VERSION', 'NOTICE.txt', '.yardopts', '.rspec']
  spec.license         = 'Amazon Software License'
  spec.platform        = Gem::Platform::RUBY
  spec.homepage        = 'http://github.com/aws/amazon-kinesis-client-ruby'
  spec.require_paths   = ['lib']

  spec.add_dependency('multi_json', '~> 1.0')
end