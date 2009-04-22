module MockAws
  
  class Ec2
    include MockAws::Base
    
    #-----------------------------------------------------------------
    #      Images
    #-----------------------------------------------------------------
    
    def ec2_describe_images(params = {}, image_type = nil, cache_for = nil)
      raise NotImplementedError
    end
    
    def describe_images(list = [], image_type = nil)
      raise NotImplementedError
    end
    
    def describe_images_by_owner(list = ['self'], image_type = nil)
      raise NotImplementedError
    end
    
    def describe_images_by_executable_by(list = ['self'], image_type = nil)
      raise NotImplementedError
    end
    
    def register_image(image_location)
      raise NotImplementedError
    end
    
    def deregister_image(image_id)
      raise NotImplementedError
    end
    
    def describe_image_attribute(image_id, attribute = 'launchPermission')
      raise NotImplementedError
    end
    
    def reset_image_attribute(image_id, attribute = 'launchPermission')
      raise NotImplementedError
    end
    
    def modify_image_attribute(image_id, attribute, operation_type = nil, vars = {})
      raise NotImplementedError
    end
    
    def modify_image_launch_perm_add_users(image_id, user_id = [])
      # raise NotImplementedError
      true
    end

    def modify_image_launch_perm_remove_users(image_id, user_id = [])
      raise NotImplementedError
    end

    def modify_image_launch_perm_add_groups(image_id, user_group = ['all'])
      raise NotImplementedError
    end
    
    def modify_image_launch_perm_remove_groups(image_id, user_group = ['all'])
      raise NotImplementedError
    end
    
    def modify_image_product_code(image_id, product_code = [])
      raise NotImplementedError
    end
    
    #-----------------------------------------------------------------
    #      Instances
    #-----------------------------------------------------------------

    def get_desc_instances(instances)
      raise NotImplementedError
    end

    def describe_instances(list = [])
      query = list && !list.empty? ? { :id => list } : {}
      account.instances.all(query).map { |inst| inst.to_aws }
    end

    def confirm_product_instance(instance, product_code)
      raise NotImplementedError
    end

    def run_instances(image_id, min_count, max_count, group_ids, key_name, user_data = '', addressing_type = nil,
                      instance_type = nil, kernel_id = nil, ramdisk_id = nil, availability_zone = nil, block_device_mappings = nil) 
      launch_instances(image_id, { :min_count       => min_count, :max_count       => max_count,  :user_data       => user_data, 
                                   :group_ids       => group_ids, :key_name        => key_name,   :instance_type   => instance_type, 
                                   :kernel_id       => kernel_id, :ramdisk_id      => ramdisk_id, :addressing_type => addressing_type,
                                   :availability_zone => availability_zone, :block_device_mappings => block_device_mappings })
    end

    def launch_instances(image_id, lparams = {})
      params = { :min_count => 1, :max_count => 1, :group_ids => ['default'], :instance_type => RightAws::Ec2::DEFAULT_INSTANCE_TYPE,
                 :addressing_type => RightAws::Ec2::DEFAULT_ADDRESSING_TYPE, :aws_image_id => image_id}.merge(lparams)
                 
      params.delete(:min_count)
      params.delete(:max_count)
      params[:aws_instance_type] = params.delete(:instance_type)
                 
      account.instances.create(params).to_launched_aws
    end

    def terminate_instances(list = [])
      instances = account.instances.all(:id => list)
      instances.each { |i| i.destroy }
      instances.map  { |i| i.to_aws.merge(:aws_state => 'shutting-down')  }
    end

    def get_console_output(instance_id)
      raise NotImplementedError
    end

    def reboot_instances(list)
      raise NotImplementedError
    end
    
    #-----------------------------------------------------------------
    #      Instances: Windows addons
    #-----------------------------------------------------------------

    def get_initial_password(instance_id, private_key)
      raise NotImplementedError
    end

    def bundle_instance(instance_id, s3_bucket, s3_prefix, s3_owner_aws_access_key_id = nil, s3_owner_aws_secret_access_key = nil,
                        s3_expires = S3Interface::DEFAULT_EXPIRES_AFTER, s3_upload_policy = 'ec2-bundle-read')
      raise NotImplementedError
    end

    def describe_bundle_tasks(list = [])
      raise NotImplementedError
    end

    def cancel_bundle_task(bundle_id)
      raise NotImplementedError
    end
    
    #-----------------------------------------------------------------
    #      Security groups
    #-----------------------------------------------------------------
    
    def describe_security_groups(list = [])
      query = list && !list.empty? ? { :aws_group_name => list } : {}
      account.security_groups.all(query).map { |kp| kp.to_aws }
    end
    
    def create_security_group(name, description)
      account.security_groups.create(:aws_group_name => name, :aws_description => description) && true
    end

    def delete_security_group(name)
      group = account.security_groups.first(:aws_group_name => name)
      group && group.destroy
    end

    def authorize_security_group_named_ingress(name, owner, group)
      true # there's no real way to verify this through the Amazon API
    end

    def revoke_security_group_named_ingress(name, owner, group)
      raise NotImplementedError
    end
    
    def authorize_security_group_IP_ingress(name, from_port, to_port, protocol = 'tcp', cidr_ip = '0.0.0.0/0')
      # raise NotImplementedError
      true
    end
    
    def revoke_security_group_IP_ingress(name, from_port, to_port, protocol = 'tcp', cidr_ip = '0.0.0.0/0')
      raise NotImplementedError
    end
  
    #-----------------------------------------------------------------
    #      Keys
    #-----------------------------------------------------------------
    
    def describe_key_pairs(list = [])
      query = list && !list.empty? ? { :aws_key_name => list } : {}
      account.keypairs.all(query).map { |kp| kp.to_aws }
    end
    
    def create_key_pair(name)
      account.keypairs.create(:aws_key_name => name).to_aws
    end
    
    def delete_key_pair(name)
      account.keypairs.first(:aws_key_name => name).destroy
      true
    end
    
    #-----------------------------------------------------------------
    #      Elastic IPs
    #-----------------------------------------------------------------
    
    def allocate_address
      account.addresses.create.value
    end
    
    def associate_address(instance_id, public_ip)
      instance = account.instances.get(instance_id) or MockAws.error(:instance_not_found, "The instance '#{instance_id}' does not exist.")
      address  = account.addresses.get(public_ip)
      
      # Raise error if instance already has an address
      instance.address = address
      instance.save
      true
    end
    
    def describe_addresses(list = [])
      query = list && !list.empty? ? { :value => list } : {}
      account.addresses.all(query).map { |ip| ip.to_aws }
    end
    
    def disassociate_address(public_ip)
      raise NotImplementedError
    end
    
    def release_address(public_ip)
      MockAws.error(:auth_failure, "The address #{public_ip} does not belong to you") unless ip = account.addresses.first(:value => public_ip)
      ip.destroy && true
    end
    
    #-----------------------------------------------------------------
    #      Availability zones
    #-----------------------------------------------------------------

    def describe_availability_zones(list = [])
      [{:zone_state => "available", :zone_name => "us-east-1a"}, 
       {:zone_state => "available", :zone_name => "us-east-1b"}, 
       {:zone_state => "available", :zone_name => "us-east-1c"}]
    end

    #-----------------------------------------------------------------
    #      EBS: Volumes
    #-----------------------------------------------------------------

    def describe_volumes(list = [])
      query = list && !list.empty? ? { :id => list } : {}
      account.volumes.all(query).map { |kp| kp.to_aws }
    end

    def create_volume(snapshot_id = nil, size = nil, zone = nil)
      params = { :snapshot_id => snapshot_id, :aws_status => 'creating', :zone => zone, :aws_created_at => Time.now, :aws_size => size }
      account.volumes.create(params).to_launched_aws
    end

    def delete_volume(volume_id)
      # volume = account.volumes.get(volume_id) or MockAws.error(:volume_not_found, "The volume '#{volume_id}' does not exist.")
      if volume = account.volumes.get(volume_id)
        volume.destroy
        volume.to_aws
      end
    end

    def attach_volume(volume_id, instance_id, device)
      volume   = account.volumes.get(volume_id)     or MockAws.error(:volume_not_found, "The volume '#{volume_id}' does not exist.")
      instance = account.instances.get(instance_id) or MockAws.error(:instance_not_found, "The instance '#{instance_id}' does not exist.")
      
      instance.attach(volume, device)
      volume.reload.to_aws
    end

    def detach_volume(volume_id, instance_id = nil, device = nil, force = nil)
      volume = account.volumes.get(volume_id) or MockAws.error(:volume_not_found, "The volume '#{volume_id}' does not exist.")
      volume.update_attributes :instance => nil, :aws_status => "available"
      volume.to_aws
    end


    #-----------------------------------------------------------------
    #      EBS: Snapshots
    #-----------------------------------------------------------------

    def describe_snapshots(list = [])
      query = list && !list.empty? ? { :id => list } : {}
      account.snapshots.all(query).map { |snap| snap.to_aws }
    end

    def create_snapshot(volume_id)
      params = {:volume_id=>volume_id, :aws_started_at=>Time.now, :aws_progress=>"100%", :aws_status=>"completed"}
      account.snapshots.create(params).to_pending_aws
    end

    def delete_snapshot(snapshot_id)
      if snapshot = account.snapshots.get(snapshot_id)
        snapshot.destroy
        snapshot.to_aws
      end
    end
    
  end
  
end
