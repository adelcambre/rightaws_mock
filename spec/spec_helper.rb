SPEC_ROOT = File.dirname(__FILE__)
$LOAD_PATH.unshift File.join(SPEC_ROOT, '..', 'lib')

require "rubygems"
require "spec"
require "mock_aws"

def be_array_of_length(length)
  simple_matcher("be Array of length #{length}") do |given, matcher|
    given.is_a?(Array) && given.length == length
  end
end

def be_hash_of_length(length)
  simple_matcher("be Hash of length #{length}") do |given, matcher|
    given.is_a?(Hash) && given.length == length
  end
end

MockAws.setup

Spec::Runner.configure do |config|
  
  config.include MockAws::SpecHelpers
  
  config.after(:each) do
    MockAws.reset!
  end
  
end