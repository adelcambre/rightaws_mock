module MockAws
  
  module Base
    
    def initialize(access_key_id = nil, secret_access_key = nil, params = {})
      @access_key_id     = access_key_id     || ENV['AWS_ACCESS_KEY_ID']
      @secret_access_key = secret_access_key || ENV['AWS_SECRET_ACCESS_KEY']
      @params            = params
    end
    
    def account
      repository(:mock_aws) do
        Account.authenticate(@access_key_id, @secret_access_key)
      end
    end
    
    def config
      MockAws.config
    end
    
  end
  
end