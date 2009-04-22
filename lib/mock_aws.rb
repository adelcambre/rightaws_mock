require "right_aws"
require "dm-core"


require File.dirname(__FILE__) + "/mock_aws/base"
require File.dirname(__FILE__) + "/mock_aws/account"
require File.dirname(__FILE__) + "/mock_aws/ec2"
require File.dirname(__FILE__) + "/mock_aws/spec"

module MockAws
  
  def self.config
    {
      :address_limit => 5
    }
  end
  
  def self.setup
    DataMapper.setup(:mock_aws, 'sqlite3::memory:')
    migrate!
  end
  
  
  # Removes all currently registered mock AWS accounts. This basically resets
  # the entire state of MockAws
  def self.reset!
    migrate!
  end
  
  def self.migrate!
    mock_aws_models = DataMapper::Resource.descendants.select {|x| x.default_repository_name == :mock_aws}
    mock_aws_models.map {|x| x.auto_migrate!(:mock_aws) }
  end
  
  def self.hex(length)
    (1..length).map { %w(1 2 3 4 5 6 7 8 9 0 a b c d e f)[rand(16)] }
  end
  
end