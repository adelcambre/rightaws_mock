require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe MockAws::Ec2 do
  
  before(:each) do
    MockAws::Account.register("hello", "world")
  end
  
  describe "key pairs" do
    
    before(:each) do
      @ec2 = MockAws::Ec2.new("hello", "world")
    end
    
    describe "#describe_key_pairs" do
      
      it "should describe all created keypairs" do
        @ec2.create_key_pair("my-keypair")
        @ec2.create_key_pair("my-keypair2")
        @ec2.describe_key_pairs.should be_array_of_length(2)
      end
      
      it "should describe the requested keypair" do
        @ec2.create_key_pair("my-keypair")
        keypairs = @ec2.describe_key_pairs("my-keypair")
        keypairs.should be_array_of_length(1)
        keypairs.first[:aws_key_name].should == "my-keypair"
      end
    end
    
    describe "#create_key_pair" do
      
      before(:each) do
        @ec2.create_key_pair("my-keypair")
      end
      
      it "should create a new key pair" do
        MockAws["hello"].should only_have_keypair("my-keypair")
      end
      
      it "should be able to create multiple keypairs" do
        @ec2.create_key_pair("my-keypair-2")
        MockAws["hello"].should only_have_keypairs("my-keypair", "my-keypair-2")
      end
      
      it "should raise an error when creating a duplicate key pair" do
        lambda { @ec2.create_key_pair("my-keypair") }.should raise_error(RightAws::AwsError)
      end
    end
    
    describe "#delete_key_pair" do
      
      before(:each) do
        @ec2.create_key_pair("my-keypair-1")
        @ec2.create_key_pair("my-keypair-2")
      end
      
      it "should delete the keypair from the account and return true" do
        @ec2.delete_key_pair("my-keypair-1").should be_true
        MockAws["hello"].should only_have_keypair("my-keypair-2")
      end
    end
  end
  
  describe "IP addresses" do
    
    before(:each) do
      @ec2     = MockAws::Ec2.new("hello", "world")
      @address = @ec2.allocate_address
    end
    
    describe "#allocate_address" do
      it "should generate a valid IP address" do
        @address.should be_ip_address
      end
      
      it "should save the address with the account" do
        MockAws["hello"].should have(1).addresses
        MockAws["hello"].addresses.first.should be_ip_address
      end
      
      it "should keep track of all IPs" do
        array = @address, @ec2.allocate_address
        MockAws["hello"].addresses.sort.should == array.sort
      end
      
      it "should raise an error when there are already 5 IP addresses registered" do
        4.times { @ec2.allocate_address }
        lambda { @ec2.allocate_address }.should raise_error(RightAws::AwsError)
      end
    end
    
    describe "#describe_addresses" do
      it "should describe the requested IP addresses associated with the account" do
        MockAws["hello"].addresses.first.should == @ec2.describe_addresses.first[:public_ip]
        pending do
          MockAws["hello"].addresses[:instance_id].should_not be_nil
        end
      end
    end
    
    describe "#associate_address" do
      it "needs specs"
    end
    
    describe "#disassociate_address" do
      it "needs specs"
    end
    
    describe "#release_address" do
      it "should return true and remove the address" do
        @ec2.release_address(@address).should be_true
        MockAws["hello"].should have(:no).addresses
      end
      
      it "should leave any other addresses" do
        addr = @ec2.allocate_address
        @ec2.release_address(@address).should be_true
        MockAws["hello"].should only_have_ip_address(addr)
      end
      
      it "should raise an error if you try and release and ip you haven't allocated" do
        lambda {
          @ec2.release_address('10.10.10.10')
        }.should raise_error(RightAws::AwsError)
      end
    end
  end
  
  describe "Security Groups" do
    
    before(:each) do
      @ec2 = MockAws::Ec2.new("hello", "world")
      @ec2.create_security_group("my-first-group", "my-first-group-desc")
    end
    
    it "should always contain a default group" do
      MockAws["hello"].should have_security_group("default")
    end
    
    it "should create a security group for a user" do
      MockAws["hello"].should have_security_group("my-first-group", :aws_description => "my-first-group-desc")
    end
    
    it "should create multiple security groups" do
      @ec2.create_security_group("my-sec-group", "my-sec-group-desc")
      MockAws["hello"].security_groups.should be_array_of_length(3)
      MockAws["hello"].security_groups.map {|g| g.aws_group_name }.should include("default", "my-first-group", "my-sec-group")
    end
    
    it "should raise an exception if you attempt to create a security group with a name that already exists" do      
      lambda{
        @ec2.create_security_group("my-first-group", "my-first-group-desc-again")
      }.should raise_error(RightAws::AwsError)
    end
    
    it "should describe currently defined security groups for a given user" do
      @ec2.create_security_group("my-first-group-again", "my-first-group-desc-again")      
      groups = @ec2.describe_security_groups
      groups.should be_array_of_length(3)
      groups.should include(:aws_group_name => "my-first-group",       :aws_description => "my-first-group-desc",       :aws_owner => MockAws["hello"].id, :aws_perms => [])
      groups.should include(:aws_group_name => "my-first-group-again", :aws_description => "my-first-group-desc-again", :aws_owner => MockAws["hello"].id, :aws_perms => [])
    end
    
  end
  
  describe "Instances" do
    
    before(:each) do
      @ec2 = MockAws::Ec2.new("hello", "world")
    end
    
    it "should create a valid instance" do
      @ec2.launch_instances("foobar")
      MockAws["hello"].instances.should be_array_of_length(1)
      MockAws["hello"].should have_instance(:id => /^i-\w{8}$/, :aws_reservation_id => /^r-\w{8}$/, :aws_owner => MockAws["hello"].id)
      MockAws["hello"].instances.first.should only_have_security_group('default')
    end
    
    it "should return a launch info hash" do
      retval = @ec2.launch_instances("foobar").first
      retval.should include(:aws_owner => MockAws["hello"].id)
    end
    
    it "should return a blank array when there are no instances" do
      @ec2.describe_instances.should be_empty
    end
    
    it "should return the instances" do
      retval = @ec2.launch_instances("foobar").first
      retval[:aws_image_id].should == "foobar"
    end
    
    it "should associate addresses" do
      address  = @ec2.allocate_address
      instance = @ec2.launch_instances("foobar").first
      
      @ec2.associate_address(instance[:aws_instance_id], address)
      MockAws["hello"].instances.first.address.value.should == address
    end
  end
  
  describe "Snapshots" do
    before(:each) do
      @ec2 = MockAws::Ec2.new("hello", "world")
      @vol = @ec2.create_volume(nil, 10, "purple")
      @snapshot = @ec2.create_snapshot(@vol[:aws_id])
    end
    
    it "should create a snapshot" do
      @snapshot.should_not be_nil
      @ec2.describe_snapshots.size.should == 1
    end
    
    it "should delete a snapshot" do
      @ec2.delete_snapshot(@snapshot[:aws_id])
    end
  end
  
  describe "Volumes" do
    
    before(:each) do
      @ec2 = MockAws::Ec2.new("hello", "world")
    end
    
    it "should create a valid volume" do
      @ec2.create_volume("snap-foo", 10, "purple")
      MockAws["hello"].volumes.should be_array_of_length(1)
    end
    
    it "should return an empty array if there are no volumes to describe" do
      @ec2.describe_volumes.should be_empty
    end
    
    it "should describe all of the instances associated with an account" do
      vol1 = @ec2.create_volume("snap-foo", 10, "purple")
      vol2 = @ec2.create_volume("snap-foo", 10, "yellow")
      
      MockAws["hello"].should have_volumes(vol1[:aws_id], vol2[:aws_id], :aws_size => 10)
    end
    
    it "should describe only the instance associated with an account" do
      vol1 = @ec2.create_volume("snap-foo", 10, "purple")
      vol2 = @ec2.create_volume("snap-foo", 10, "yellow")
      
      MockAws["hello"].should only_have_volumes(vol1[:aws_id], vol2[:aws_id], :aws_size => 10)
    end
    
    it "should attach a volume to a given instance" do
      volume   = @ec2.create_volume("snap-000100", 10, "zonez")
      instance = @ec2.launch_instances("pantz").first
      retval   = @ec2.attach_volume(volume[:aws_id], instance[:aws_instance_id], '/dev/sda')

      retval[:aws_instance_id].should == instance[:aws_instance_id]
      retval[:aws_status].should      == 'attached'
      retval[:aws_device].should      == '/dev/sda'
    end
    
    it "should be able to detatch a volume" do
      volume = @ec2.create_volume("snap-bob", 10, "pink")
      instance = @ec2.launch_instances("pantz").first
      @ec2.attach_volume(volume[:aws_id], instance[:aws_instance_id], '/dev/sda')
      @ec2.detach_volume(volume[:aws_id])
      
      MockAws["hello"].instances.first.volumes.should be_empty
    end
    
    it "should be able to delete a volume" do
      volume = @ec2.create_volume("snap-bob", 10, "pink")
      @ec2.delete_volume(volume[:aws_id])
      
      MockAws["hello"].should_not have_volume(volume[:aws_id])
    end
    
    describe "Destroying instances" do
      
      before(:each) do
        @instance1 = @ec2.launch_instances("alice").first
        @instance2 = @ec2.launch_instances("cooper").first
      end
      
      it "should be able to terminate a bunch of instances" do
        @ec2.terminate_instances([@instance1[:aws_instance_id], @instance2[:aws_instance_id]])
        MockAws["hello"].instances.should be_empty
      end
      
      it "should be able to selectively terminate instances" do
        @ec2.terminate_instances([@instance1[:aws_instance_id]])
        MockAws["hello"].instances.length.should == 1
        MockAws["hello"].instances.first.id.should == @instance2[:aws_instance_id]
      end
      
      it "should return the AWS descriptions of destroyed instances" do
        retval = @ec2.terminate_instances([@instance1[:aws_instance_id]])
        retval.first[:aws_image_id].should == @instance1[:aws_image_id]
        retval.first[:aws_owner].should    == MockAws["hello"].id
        retval.first[:aws_state].should    == "shutting-down"
      end
      
      it "should release any attached volumes" do
        volume = @ec2.create_volume(nil, 10, 'ping')
        @ec2.attach_volume(volume[:aws_id], @instance1[:aws_instance_id], '/dev/sda')
        @ec2.terminate_instances([@instance1[:aws_instance_id]])
        MockAws["hello"].should have_volumes(:aws_status => "available")
      end
      
    end
    
  end
end