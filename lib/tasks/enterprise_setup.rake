namespace :enterprise do
  desc 'Enable enterprise features permanently for testing/fork purposes'
  task :enable_features => :environment do
    puts "🚀 Setting up Enterprise features..."

    # Set pricing plan to enterprise
    config = InstallationConfig.find_or_initialize_by(name: 'INSTALLATION_PRICING_PLAN')
    config.value = 'enterprise'
    config.locked = false # Allow manual changes
    config.save!
    puts "✅ Set pricing plan to: enterprise"

    # Set quantity (optional, for user limits)
    quantity_config = InstallationConfig.find_or_initialize_by(name: 'INSTALLATION_PRICING_PLAN_QUANTITY')
    quantity_config.value = 999 # High number for testing
    quantity_config.locked = false
    quantity_config.save!
    puts "✅ Set plan quantity to: 999"

    # Enable features for all accounts
    enterprise_features = %w[
      disable_branding
      audit_logs
      sla
      custom_roles
      captain_integration
      inbound_emails
      help_center
      campaigns
      team_management
      channel_twitter
      channel_facebook
      channel_email
      channel_instagram
    ]

    Account.find_each do |account|
      account.enable_features!(*enterprise_features)
      puts "✅ Enabled enterprise features for account: #{account.name}"
    end

    puts ""
    puts "🎉 Enterprise features have been enabled!"
    puts "🔒 The scheduled job has been disabled to prevent feature removal."
    puts "📋 Features enabled: #{enterprise_features.join(', ')}"
    puts ""
    puts "To check current pricing plan status:"
    puts "rails console"
    puts "> ChatwootHub.pricing_plan"
    puts "> Account.first.enabled_features"
  end

  desc 'Show current enterprise status'
  task :status => :environment do
    puts "📊 Current Enterprise Status:"
    puts "Pricing Plan: #{ChatwootHub.pricing_plan}"
    puts "Plan Quantity: #{ChatwootHub.pricing_plan_quantity}"
    puts ""
    
    Account.find_each do |account|
      puts "Account: #{account.name}"
      puts "  Enabled features: #{account.enabled_features.join(', ')}"
      puts ""
    end
  end
end
