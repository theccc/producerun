module CatarseBraintree
  class Gateway
    def initialize(configuration = PaymentEngines.configuration)
      @configuration = configuration
    end

    def self.instance
      new.setup_gateway
    rescue Exception => e
      puts e.message
      Rails.logger.warn e.message
    end

    def setup_gateway
      check_default_configurations!
      Rails.logger.debug @configuration[:braintree_merchant_id]
      Braintree::Configuration.environment = !!@configuration[:braintree_test] ? :sandbox : :production
      Braintree::Configuration.merchant_id = "jnp9mrw7jcfhdxd5"
      Braintree::Configuration.public_key  = "dk4gvgnsp95yhjb2"
      Braintree::Configuration.private_key = "b02e9a2884ced1ec00ec3a26cb749489"
      self
    end


    def generate_client_token
      Braintree::ClientToken.generate
    end

    private

    def check_default_configurations!
      %i(braintree_merchant_id braintree_public_key braintree_private_key braintree_test).each do |key|
        raise pending_configuration_message(key) unless @configuration[key].present?
      end
    end

    def pending_configuration_message(key)
      "[Braintree] Please ensure the #{key} option is configured"
    end
  end
end
