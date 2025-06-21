module Jira::IntegrationHelper
  # Generates a signed JWT token for JIRA integration with site URL and account info
  #
  # @param account_id [Integer] The account ID to encode in the token
  # @param site_url [String] The JIRA site URL
  # @return [String, nil] The encoded JWT token or nil if client secret is missing
  def generate_jira_token(account_id, site_url)
    return if client_secret.blank?
    
    JWT.encode(jira_token_payload(account_id, site_url), client_secret, 'HS256')
  rescue StandardError => e
    Rails.logger.error("Failed to generate JIRA token: #{e.message}")
    nil
  end

  def jira_token_payload(account_id, site_url)
    {
      sub: account_id,
      site_url: site_url,
      iat: Time.current.to_i,
      exp: Time.current.to_i + 1.hour.to_i # Token expires in 1 hour
    }
  end

  # Verifies and decodes a JIRA JWT token
  #
  # @param token [String] The JWT token to verify
  # @return [Hash, nil] The decoded payload or nil if invalid
  def verify_jira_token(token)
    return if token.blank? || client_secret.blank?
    
    decode_token(token, client_secret)
  end

  # Builds JIRA OAuth authorization URL with proper state
  #
  # @param account_id [Integer] The account ID
  # @param site_url [String] The JIRA site URL
  # @return [String] The authorization URL
  def build_jira_oauth_url(account_id, site_url)
    client_id = GlobalConfigService.load('JIRA_CLIENT_ID', nil)
    return nil if client_id.blank?

    state = generate_jira_token(account_id, site_url)
    callback_uri = "#{frontend_url}/jira/callback"

    "#{site_url}/plugins/servlet/oauth/authorize?" \
    "response_type=code&" \
    "client_id=#{client_id}&" \
    "redirect_uri=#{CGI.escape(callback_uri)}&" \
    "state=#{state}&" \
    "scope=read:jira-work write:jira-work"
  end

  private

  def client_secret
    @client_secret ||= GlobalConfigService.load('JIRA_CLIENT_SECRET', nil)
  end

  def decode_token(token, secret)
    payload, _header = JWT.decode(token, secret, true, { algorithm: 'HS256' })
    payload.with_indifferent_access
  rescue JWT::DecodeError => e
    Rails.logger.error("JWT decode error: #{e.message}")
    nil
  end

  def frontend_url
    ENV.fetch('FRONTEND_URL', GlobalConfigService.load('FRONTEND_URL', 'http://localhost:3000'))
  end

  # Decode state parameter from OAuth callback
  def decode_state(state_param)
    return nil if state_param.blank?
    
    verify_jira_token(state_param)
  end
end
