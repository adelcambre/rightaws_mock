module MockAws
  
  module SpecHelpers
    
    def have_keypairs(*names)
      simple_matcher("have keypair(s) '#{names.inspect}'") do |given, matcher|
        matcher.failure_message = "expected AWS account to have keypair(s) named #{names.inspect}, instead it contained #{given.keypairs.map { |i| i.to_aws }.inspect}."
        matcher.negative_failure_message = "expected AWS account not to have keypair(s) named #{names.inspect}, but it did."
        names.all? { |name| given.keypairs.map { |kp| kp.aws_key_name }.include?(name) }
      end
    end
    
    alias_method :have_keypair, :have_keypairs
    
    def only_have_keypairs(*names)
      simple_matcher("only have keypair(s) '#{names.inspect}'") do |given, matcher|
        matcher.failure_message = "expected AWS account to only have keypair(s) named #{names.inspect}, instead it contained #{given.keypairs.map { |i| i.to_aws }.inspect}."
        matcher.negative_failure_message = "expected AWS account not to only have keypair(s) named #{names.inspect}, but it did."
        given.keypairs.length == names.length && names.all? { |name| given.keypairs.map { |kp| kp.aws_key_name }.include?(name) }
      end
    end
    
    alias_method :only_have_keypair, :only_have_keypairs
    
    def be_ip_address
      match(/\d{1,3}(\.\d{1,3}){3}/)
    end
    
    def have_ip_addresses(*addresses)
      simple_matcher("have IP address '#{addresses.inspect}'") do |given, matcher|
        addresses.all? { |addr| given.addresses.should include(addr) }
      end
    end
    
    alias_method :have_ip_address, :have_ip_addresses
    
    def only_have_ip_addresses(*addresses)
      simple_matcher("have IP address '#{addresses.inspect}'") do |given, matcher|
        given.addresses.length == addresses.length && addresses.all? { |addr| given.addresses.should include(addr) }
      end
    end
    
    alias_method :only_have_ip_address, :only_have_ip_addresses
    
    def have_security_group(name, options = {})
      simple_matcher("have security group") do |given, matcher|
        given.security_groups.reload
        base_message  = "to have a security group named '#{name}'"
        base_message += " with #{options.map{|k,v| "#{k} = #{v}"}.join(', ')}" if options.any?
        matcher.failure_message = "expected AWS account #{base_message}, but it was #{given.security_groups.map { |i| i.to_aws }.inspect}"
        
        group = name.is_a?(Regexp) ? given.security_groups.detect { |g| g.aws_group_name =~ name } : given.security_groups.first(:aws_group_name => name)
        group && options.all? { |key, value| group.send(key) == value }
      end
    end
    
    def only_have_security_group(name, options = {})
      simple_matcher("have security group") do |given, matcher|
        base_message  = "to have a security group named '#{name}'"
        base_message += " with #{options.map{|k,v| "#{k} = #{v}"}.join(', ')}" if options.any?
        matcher.failure_message = "expected AWS account #{base_message}, but it was #{given.security_groups.all.map { |i| i.to_aws }.inspect}"
        group = name.is_a?(Regexp) ? given.security_groups.all.detect { |g| g.aws_group_name =~ name } : given.security_groups.all.first(:aws_group_name => name)
        group && given.security_groups.all.length == 1 && options.all? { |key, value| group[key] == value }
      end
    end
    
    def have_instance(options = {})
      simple_matcher("have instance") do |given, matcher|
        base_message  = "to have an instance"
        base_message += " with #{options.map{|k,v| "#{k} = #{v}"}.join(', ')}" if options.any?
        matcher.failure_message = "expected AWS account #{base_message}, but it was #{given.instances.map { |i| i.to_aws }.inspect}"
        given.instances.detect do |inst|
          options.all? do |k, v|
            actual = inst.send(k)
            v.is_a?(Regexp) && !actual.is_a?(Regexp) ? actual =~ v : actual == v
          end
        end # given
      end # simple_matcher
    end
    
    def have_volumes(*volumes)
      options = volumes.last.is_a?(Hash) ? volumes.pop : {}
      
      simple_matcher("have volume") do |given, matcher|
        given.volumes.reload
        base_message  = "to have volumes named '#{volumes.inspect}'"
        base_message += " with #{options.map{|k,v| "#{k} = #{v}"}.join(', ')}" if options.any?
        matcher.failure_message = "expected AWS account #{base_message}, but it was #{given.volumes.map { |v| v.to_aws }.inspect}"
        
        if volumes.any?
          actual = given.volumes.all.reject do |actual|
            !volumes.include?(actual.id) || options.any? { |key, value| actual.send(key) != value }
          end
          
          actual.length == volumes.length
        else
          given.volumes.all.any? do |actual|
            options.all? { |key, value| actual.send(key) == value }
          end
        end
      end
    end
    
    alias_method :have_volume, :have_volumes
    
    def only_have_volumes(*volumes)
      options = volumes.last.is_a?(Hash) ? volumes.pop : {}
      
      simple_matcher("have volume") do |given, matcher|
        given.volumes.reload
        base_message  = "to have volumes named '#{volumes.inspect}'"
        base_message += " with #{options.map{|k,v| "#{k} = #{v}"}.join(', ')}" if options.any?
        matcher.failure_message = "expected AWS account #{base_message}, but it was #{given.volumes.map { |v| v.to_aws }.inspect}"
        
        if volumes.any?
          bad_volumes = given.volumes.all.reject do |actual|
            volumes.include?(actual.id) && options.all? { |key, value| actual.send(key) == value }
          end
          
          bad_volumes.length == 0
        else
          given.volumes.all.all? do |actual|
            options.all? { |key, value| actual.send(key) == value }
          end
        end
      end
    end
    
  end
  
end