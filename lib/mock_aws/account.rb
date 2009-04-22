require 'randexp'

module MockAws
  
  # A shorter way to access the accounts Hash
  def self.[](access_key_id)
    Account.first(:access_key_id => access_key_id)
  end
  
  # Raises an AWS error. Error raising happens through here so that errors can be mapped
  # to the actual errors raised by RightAws in one spot instead of having RightAws errors
  # hard coded throughout the mock.
  def self.error(error, message)
    message = case error
      when :auth_failure       then "AuthFailure: #{message}"
      when :duplicate_group    then "InvalidGroup.Duplicate: #{message}"
      when :duplicate_keypair  then "InvalidKeyPair.Duplicate: #{message}"
      when :address_limit      then "AddressLimitExceeded: #{message}"
      when :volume_not_found   then "InvalidVolume.NotFound: #{message}"
      when :instance_not_found then "InvalidInstanceID.NotFound: #{message}"
    end
    
    raise RightAws::AwsError, message
  end
  
  #-----------------------------------------------------------------
  #      Models
  #-----------------------------------------------------------------
  
  class Account
    include DataMapper::Resource
    def self.default_repository_name ; :mock_aws ; end
    
    property :id,                Serial
    property :access_key_id,     String
    property :secret_access_key, String
    
    has n, :addresses
    has n, :keypairs
    has n, :security_groups
    has n, :instances
    has n, :volumes
    has n, :snapshots
    
    after :create, :initialize_associations
    
    def self.register(access_key_id, secret_access_key)
      repository(:mock_aws) do
        first_or_create(:access_key_id => access_key_id, :secret_access_key => secret_access_key) if access_key_id && secret_access_key
      end
    end
    
    # Authenticates and returns the Account object. The authentication happens against
    # the access_key_id and secret_access_key. An error is raised if an account could
    # not be authenticated
    def self.authenticate(access_key_id, secret_access_key)
      account = first(:access_key_id => access_key_id)
      
      if !account || account.secret_access_key != secret_access_key
        MockAws.error(:auth_failure, "AWS was not able to validate the provided access credentials")
      end

      account
    end
    
    def add_address!
      addresses.create
    end
  
  private
  
    def initialize_associations
      security_groups.create(:aws_group_name => "default", :aws_description => "default group")
    end
  end
  
  class Instance
    include DataMapper::Resource
    def self.default_repository_name ; :mock_aws ; end
    
    property :id,                 String, :key => true
    property :aws_instance_type,  String
    property :aws_image_id,       String
    property :aws_reservation_id, String
    property :aws_state,          String, :default => "running"
    property :aws_reason,         String, :default => ""
    property :aws_state_code,     String, :default => "16"
    property :dns_name,           String
    property :private_dns_name,   String, :default => lambda { /private-10-\d{3}-\d{3}-\d{3}.aws.amazon.com/.generate }
    property :aws_ramdisk_id,     String
    property :aws_kernel_id,      String
    property :aws_launch_time,    String
    property :addressing_type,    String
    property :availability_zone,  String
    property :user_data,          String, :length => 4_096
    
    attr_accessor :group_ids, :key_name
    
    belongs_to :account
    belongs_to :keypair
    
    has n, :volumes
    has 1, :address, :class_name => "MockAws::Address"
    has n, :instance_x_security_groups
    has n, :security_groups, :through => :instance_x_security_groups
    
    before :create,  :set_ids
    before :create,  :handle_associations
    after  :create,  :handle_joins
    before :destroy, :release_volumes
    
    def to_aws
      aws_state == 'running' ?   # just running? are there others?
        to_launched_aws[0] :
        { :aws_image_id => aws_image_id, :aws_owner => account.id, :aws_state => aws_state }
    end
    
    def to_launched_aws
      [{
        :aws_image_id    => aws_image_id,       :aws_reason       => aws_reason,        :aws_state_code     => "16",
        :aws_owner       => account.id,         :aws_instance_id  => id,                :aws_reservation_id => aws_reservation_id,
        :aws_state       => aws_state,          :dns_name         => dns_name,          :ssh_key_name       => keypair ? keypair.aws_key_name : "",
        :aws_groups      => group_ids,          :private_dns_name => private_dns_name,  :aws_instance_type  => aws_instance_type,
        :aws_ramdisk_id  => aws_ramdisk_id,     :aws_kernel_id    => aws_kernel_id,     :ami_launch_index   => "0",
        :aws_launch_time => aws_launch_time
      }]
    end
    
    def group_ids
      ['default'] # security_groups.map { |g| g.aws_group_name }
    end
    
    def aws_owner
      account.id
    end
    
    def attach(volume, device)
      volume.update_attributes :aws_device => device, :aws_status => 'attached', :instance => self
    end
    
  private
    
    def set_ids
      self.id = "i-#{MockAws.hex(8)}"
      self.aws_reservation_id = "r-#{MockAws.hex(8)}"
      self.aws_ramdisk_id     = "ari-#{MockAws.hex(8)}"
      self.aws_kernel_id      = "aki-#{MockAws.hex(8)}"
      self.aws_launch_time    = Time.now.strftime("%Y-%m-%dT%H:%m:%S.000Z")
    end
    
    def release_volumes
      volumes.reload.each do |vol|
        vol.update_attributes :instance => nil, :aws_status => "available"
      end
    end
    
    def handle_associations
      if @key_name && !(key = account.keypairs.first(:aws_key_name => @key_name))
        MockAws.error(:keypair_not_found, "The key pair '#{key_name}' does not exist")
      end
      
      self.keypair = key if key
    end
    
    def handle_joins
      group_ids.map { |g| account.security_groups.first(:aws_group_name => g) }.compact.each do |group|
        instance_x_security_groups.create(:security_group_id => group.id)
        # InstanceXSecurityGroup.create(:instance_id => id, :security_group_id => group.id)
      end
    end
    
  end
  
  class Address
    include DataMapper::Resource
    def self.default_repository_name ; :mock_aws ; end
    
    property :value, String, :key => true

    belongs_to :account
    belongs_to :instance
    
    before :create, :limit_per_account
    before :create, :set_value
    
    def ==(other)
      other.is_a?(String) ? value == other : super
    end
    
    def =~(pattern)
      value =~ pattern
    end
    
    def <=>(other)
      value <=> other.value
    end
    
    def to_aws
      { :instance_id => (instance && instance.id), :public_ip => value }
    end
    
  private
  
    def set_value
      self.value = (1..4).map { rand(256) }.join('.')
    end
    
    def limit_per_account
      account.addresses.reload
      raise MockAws.error(:address_limit, "Too many addresses allocated")  if account.addresses.length >= 5
    end
  
  end
  
  class Keypair
    include DataMapper::Resource
    def self.default_repository_name ; :mock_aws ; end
    
    property :id,           Serial
    property :aws_key_name, String, :null => false
    
    belongs_to :account
    
    before :create, :unique_per_account
    
    def aws_fingerprint
      "gagaga"
    end
    
    def aws_material
      "-----BEGIN RSA PRIVATE KEY-----\ngagaga\n-----END RSA PRIVATE KEY-----"
    end
    
    def to_aws
      { :aws_key_name => aws_key_name, :aws_fingerprint => aws_fingerprint, :aws_material => aws_material }
    end
    
  private
    
    def unique_per_account
      if account.keypairs.first(:aws_key_name => aws_key_name)
        MockAws.error(:duplicate_keypair, "The keypair '#{aws_key_name}' already exists.") 
      end
    end
  
  end
  
  class Volume
    include DataMapper::Resource
    def self.default_repository_name ; :mock_aws ; end
    
    property :id,                    String,   :key => true
    property :snapshot_id,           String
    property :aws_status,            String
    property :zone,                  String
    property :aws_created_at,        DateTime
    property :aws_size,              Integer
    property :aws_device,            String,   :default => nil
    property :aws_attached_at,       DateTime, :default => nil

    belongs_to :account
    belongs_to :instance
    
    before :create, :set_ids
    after :create, :to_launched_aws
    
    def to_aws      
      params = attributes.dup
      params[:aws_id] = params.delete(:id)
      params[:aws_instance_id] = params.delete(:instance_id)
      params  
    end
    
    def to_launched_aws
      params = attributes.dup
      params[:aws_id] = params.delete(:id)
      params[:aws_instance_id] = params.delete(:instance_id)
      params
    end
    
  private
    
    def set_ids
      self.id = "vol-#{MockAws.hex(8)}"
    end
  end
  
  # {:aws_volume_id=>"vol-a58264cc", :aws_started_at=>Wed Mar 18 18:07:01 UTC 2009, :aws_id=>"snap-0ced1965", :aws_progress=>"100%", :aws_status=>"completed"}
  class Snapshot
    include DataMapper::Resource
    def self.default_repository_name ; :mock_aws ; end
    
    property :id,                     String,   :key => true
    property :aws_status,             String
    property :aws_progress,           String
    property :aws_started_at,         DateTime

    belongs_to :account
    belongs_to :volume
    
    before :create, :set_ids
    after :create, :to_pending_aws
    
    def to_aws      
      params = attributes.dup
      params[:aws_id] = params.delete(:id)
      params[:aws_volume_id] = params.delete(:volume_id)
      params  
    end
    
    def to_pending_aws
      params = attributes.dup
      params[:aws_id] = params.delete(:id)
      params[:aws_volume_id] = params.delete(:volume_id)
      params[:aws_progress] = "80%"
      params[:aws_status] = "pending"
      params
    end
    
  private
    
    def set_ids
      self.id = "snap-#{MockAws.hex(8)}"
    end
  end
  
  class SecurityGroup
    include DataMapper::Resource
    def self.default_repository_name ; :mock_aws ; end
    
    property :id,              Serial
    property :aws_group_name,  String
    property :aws_description, String
    
    belongs_to :account
    has n, :instance_x_security_groups
    has n, :instances, :through => :instance_x_security_groups
    
    before :create, :unique_per_account
    
    def aws_perms
      []
    end
    
    def to_aws
      { :aws_group_name => aws_group_name, :aws_description => aws_description, :aws_owner => account.id, :aws_perms => aws_perms }
    end
    
  private
  
    def unique_per_account
      if account.security_groups.first(:aws_group_name => aws_group_name)
        MockAws.error(:duplicate_group, "The security group '#{aws_group_name}' already exists")
      end
    end
    
  end
  
  class InstanceXSecurityGroup
    include DataMapper::Resource
    def self.default_repository_name ; :mock_aws ; end
    
    property :id,                Serial
    property :instance_id,       String
    property :security_group_id, Integer
    
    belongs_to :security_group
    belongs_to :instance
  end
  
end
