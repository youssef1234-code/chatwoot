# Override for development/testing - Force unlimited enterprise features
# This patches the enterprise limits to always return unlimited values for development

# Use Rails.application.config.to_prepare to ensure this runs after all classes are loaded
Rails.application.config.to_prepare do
  # Only apply in development/test environments and if Enterprise modules exist
  if defined?(Enterprise::Account::PlanUsageAndLimits)

    # Create the override module
    unless defined?(Enterprise::Account::PlanUsageAndLimitsOverride)
      module Enterprise::Account::PlanUsageAndLimitsOverride
        def usage_limits
          # For development/testing, provide unlimited enterprise features
          {
            agents: ChatwootApp.max_limit.to_i,
            inboxes: ChatwootApp.max_limit.to_i,
            captain: {
              documents: {
                total: ChatwootApp.max_limit,
                consumed: 0,
                current_available: ChatwootApp.max_limit
              },
              responses: {
                total: ChatwootApp.max_limit,
                consumed: 0,
                current_available: ChatwootApp.max_limit
              }
            }
          }
        end

        def agent_limits
          # Return unlimited agents for development
          ChatwootApp.max_limit
        end

        def get_limits(limit_name)
          # Return unlimited for all limits in development
          ChatwootApp.max_limit
        end

        def get_captain_limits(type)
          # Return unlimited captain limits for development
          {
            total: ChatwootApp.max_limit,
            consumed: 0,
            current_available: ChatwootApp.max_limit
          }
        end
      end
    end

    # Apply the override
    Enterprise::Account::PlanUsageAndLimits.prepend(Enterprise::Account::PlanUsageAndLimitsOverride)
    Rails.logger.info '✅ Applied enterprise development overrides - unlimited features enabled'
  end
end
