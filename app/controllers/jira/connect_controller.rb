class Jira::ConnectController < ApplicationController
  include Jira::IntegrationHelper
  
  before_action :authenticate_user!
  before_action :set_current_account

  def create
    # Get the JIRA site URL and credentials from environment
    site_url = GlobalConfigService.load('JIRA_SITE_URL', nil)
    email = GlobalConfigService.load('JIRA_EMAIL', nil)
    api_token = GlobalConfigService.load('JIRA_API_TOKEN', nil)
    deployment_type = GlobalConfigService.load('JIRA_DEPLOYMENT_TYPE', 'data_center')
    
    if site_url.blank? || api_token.blank?
      render json: { error: 'JIRA credentials not configured. Please contact your administrator.' }, status: :unprocessable_entity
      return
    end

    # Cloud requires email for Basic auth; Data Center uses PAT with Bearer auth
    if deployment_type == 'cloud' && email.blank?
      render json: { error: 'JIRA email is required for Cloud deployments.' }, status: :unprocessable_entity
      return
    end
    
    account_id = @account&.id || Current.account&.id
    
    if account_id.nil?
      render json: { error: 'Authentication required. Please log in again.' }, status: :unauthorized
      return
    end
    
    # Create or update JIRA hook with appropriate authentication
    result = create_jira_hook(account_id, site_url, email, api_token, deployment_type)
    
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

  def create_jira_hook(account_id, site_url, email, api_token, deployment_type)
    begin
      account = Account.find(account_id)
      
      # Remove existing hook if any
      existing_hook = account.hooks.find_by(app_id: 'jira')
      existing_hook&.destroy!
      
      # Build settings based on deployment type
      settings = {
        site_url: site_url,
        api_token: api_token,
        deployment_type: deployment_type
      }

      if deployment_type == 'data_center'
        settings[:auth_type] = 'personal_access_token'
      else
        settings[:email] = email
        settings[:auth_type] = 'api_token'
      end

      # Create hook with credentials
      hook = account.hooks.create!(
        app_id: 'jira',
        status: 'enabled',
        reference_id: site_url,
        settings: settings
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
