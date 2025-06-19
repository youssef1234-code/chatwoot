# Force enterprise installation configuration for development/testing
Rails.application.configure do
  config.after_initialize do
    if true
      # Ensure InstallationConfig exists and is set to enterprise
      begin
        # Set the pricing plan to enterprise
        pricing_plan_config = InstallationConfig.find_or_create_by(name: 'INSTALLATION_PRICING_PLAN')
        pricing_plan_config.update!(value: 'enterprise') unless pricing_plan_config.value == 'enterprise'
        
        # Set unlimited quantity for development
        quantity_config = InstallationConfig.find_or_create_by(name: 'INSTALLATION_PRICING_PLAN_QUANTITY')
        quantity_config.update!(value: ChatwootApp.max_limit.to_s) unless quantity_config.value == ChatwootApp.max_limit.to_s
        
        Rails.logger.info "[Development Override] Forced enterprise mode with unlimited features"
      rescue => e
        # Silently fail if database is not ready (during migrations, etc.)
        Rails.logger.warn "[Development Override] Could not set enterprise config: #{e.message}"
      end
    end
  end
end
