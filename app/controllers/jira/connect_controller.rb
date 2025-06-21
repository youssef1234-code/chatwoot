class Jira::ConnectController < ApplicationController
  include Jira::IntegrationHelper
  
  before_action :authenticate_user!
  before_action :set_current_account

  def create
    # Get the JIRA site URL and credentials from environment
    site_url = GlobalConfigService.load('JIRA_SITE_URL', nil)
    email = GlobalConfigService.load('JIRA_EMAIL', nil)
    api_token = GlobalConfigService.load('JIRA_API_TOKEN', nil)
    
    if site_url.blank? || email.blank? || api_token.blank?
      render json: { error: 'JIRA credentials not configured. Please contact your administrator.' }, status: :unprocessable_entity
      return
    end
    
    account_id = @account&.id || Current.account&.id
    
    if account_id.nil?
      render json: { error: 'Authentication required. Please log in again.' }, status: :unauthorized
      return
    end
    
    # Create or update JIRA hook with API token authentication
    result = create_jira_hook(account_id, site_url, email, api_token)
    
    if result[:success]
      render json: { 
        success: true, 
        message: 'JIRA integration connected successfully!',
        hook: result[:hook]
      }, status: :ok
    else
      render json: { 
        error: result[:error] || 'Failed to connect to JIRA' 
      }, status: :unprocessable_entity
    end
  end

  private

  def set_current_account
    @account = Current.account
  end

  def create_jira_hook(account_id, site_url, email, api_token)
    begin
      account = Account.find(account_id)
      
      # Remove existing hook if any
      existing_hook = account.hooks.find_by(app_id: 'jira')
      existing_hook&.destroy!
      
      # Create hook with API token credentials
      hook = account.hooks.create!(
        app_id: 'jira',
        status: 'enabled',
        reference_id: site_url,
        settings: {
          site_url: site_url,
          email: email,
          api_token: api_token,
          auth_type: 'api_token'
        }
      )
      
      # Test the connection
      test_result = test_jira_connection(hook)
      
      if test_result[:success]
        Rails.logger.info("JIRA integration created successfully for account #{account_id}")
        { success: true, hook: hook }
      else
        hook.update!(status: 'disabled')
        Rails.logger.error("JIRA connection test failed: #{test_result[:error]}")
        { success: false, error: "Connection test failed: #{test_result[:error]}" }
      end
      
    rescue StandardError => e
      Rails.logger.error("Error creating JIRA hook: #{e.message}")
      { success: false, error: "Failed to create JIRA integration: #{e.message}" }
    end
  end

  def test_jira_connection(hook)
    begin
      processor = Integrations::Jira::ProcessorService.new(account: hook.account)
      result = processor.projects
      
      if result[:error]
        { success: false, error: result[:error] }
      else
        { success: true, data: result[:data] }
      end
    rescue StandardError => e
      { success: false, error: "Connection test failed: #{e.message}" }
    end
  end
end
