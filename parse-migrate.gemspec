# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'parse-migrate/version'

Gem::Specification.new do |spec|
  spec.name          = 'parse-migrate'
  spec.version       = Migrate::VERSION
  spec.authors       = ['Brandon Evans']
  spec.email         = ['brandon@brandonevans.ca']
  spec.description   = 'Easier migration for your Parse data'
  spec.summary       = spec.description
  spec.homepage      = 'https://github.com/interstateone/parse-migrate'
  spec.license       = 'MIT'

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.required_ruby_version = '>= 1.8.7'
  spec.add_development_dependency 'bundler', '~> 1.3'
  spec.add_development_dependency 'rake'
  spec.add_dependency 'parse-ruby-client'
end
