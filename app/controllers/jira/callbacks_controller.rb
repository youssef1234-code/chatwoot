class Jira::CallbacksController < ApplicationController
  include Jira::IntegrationHelper

  def show
    @response = oauth_client.auth_code.get_token(
      params[:code],
      redirect_uri: "#{base_url}/jira/callback"
    )

    handle_response
  rescue StandardError => e
    Rails.logger.error("JIRA callback error: #{e.message}")
    redirect_to jira_redirect_uri
  end

  private

  def oauth_client
    client_id = GlobalConfigService.load('JIRA_CLIENT_ID', nil)
    client_secret = GlobalConfigService.load('JIRA_CLIENT_SECRET', nil)
    
    # Extract site from state parameter, or use default
    site_url = extract_site_from_state || GlobalConfigService.load('JIRA_SITE_URL', 'https://your-domain.atlassian.net')

    OAuth2::Client.new(
      client_id,
      client_secret,
      {
        site: site_url,
        authorize_url: '/plugins/servlet/oauth/authorize',
        token_url: '/plugins/servlet/oauth/access-token'
      }
    )
  end

  def handle_response
    hook = account.hooks.new(
      access_token: @response.token,
      status: 'enabled',
      app_id: 'jira',
      reference_id: extract_site_from_state,
      settings: {
        token_type: @response.params['token_type'],
        expires_in: @response.params['expires_in'],
        scope: @response.params['scope'],
        site_url: extract_site_from_state,
        refresh_token: @response.refresh_token
      }
    )
    
    hook.save!
    redirect_to jira_redirect_uri
  rescue StandardError => e
    Rails.logger.error("JIRA callback error: #{e.message}")
    redirect_to jira_redirect_uri
  end

  def extract_site_from_state
    decoded_state = decode_state(params[:state])
    decoded_state&.dig('site_url') || GlobalConfigService.load('JIRA_SITE_URL', 'https://your-domain.atlassian.net')
  end

  def account
    return @account if @account

    decoded_state = decode_state(params[:state])
    if decoded_state
      account_id = decoded_state['sub']
      Rails.logger.info("JIRA OAuth: Looking for account with ID #{account_id}")
      
      if account_id
        @account = Account.find_by(id: account_id)
        Rails.logger.error("JIRA OAuth: Account not found for ID #{account_id}") unless @account
      else
        Rails.logger.error("JIRA OAuth: No account ID found in decoded state")
      end
    else
      Rails.logger.error("JIRA OAuth: Failed to decode state parameter: #{params[:state]}")
    end
    
    @account
  end

  def jira_redirect_uri
    account_id = account&.id || 'unknown'
    
    if account_id == 'unknown'
      "#{frontend_url}/app/settings/integrations"
    else
      "#{frontend_url}/app/accounts/#{account_id}/settings/integrations/jira"
    end
  end

  def frontend_url
    ENV.fetch('FRONTEND_URL', GlobalConfigService.load('FRONTEND_URL', 'http://localhost:3000'))
  end

  def base_url
    ENV.fetch('FRONTEND_URL', GlobalConfigService.load('FRONTEND_URL', 'http://localhost:3000'))
  end

  def decode_state(state_param)
    return nil if state_param.blank?
    
    Rails.logger.info("JIRA OAuth: Attempting to decode state parameter")
    result = verify_jira_token(state_param)
    
    if result
      Rails.logger.info("JIRA OAuth: Successfully decoded state: #{result.inspect}")
    else
      Rails.logger.error("JIRA OAuth: Failed to decode state parameter")
    end
    
    result
  end
end
