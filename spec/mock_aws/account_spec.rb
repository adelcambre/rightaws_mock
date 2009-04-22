require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe MockAws::Account do
  
  describe "#register" do
    it "should register an account" do
      MockAws::Account.register("hello", "world")
      MockAws["hello"].should be_instance_of(MockAws::Account)
    end
  end
  
  describe "#reset!" do
    it "should be able to reset the mock object" do
      MockAws::Account.register("hello", "world")
      MockAws.reset!
      MockAws::Account.all.should be_empty
    end
  end
  
  describe "#authenticate" do
    
    before(:each) do
      MockAws::Account.register("hello", "world")
    end
    
    it "should return the account when called with valid credentials" do
      MockAws::Account.authenticate("hello", "world").should be_instance_of(MockAws::Account)
    end
    
    it "should raise an error when called with an invalid access_key_id" do
      lambda { MockAws::Account.authenticate("goodbye", "world") }.should raise_error(RightAws::AwsError)
    end
    
    it "should raise an error when called with an invalid secret_key" do
      lambda { MockAws::Account.authenticate("hello", "daffodil") }.should raise_error(RightAws::AwsError)
    end
  end
  
end