module Plane::IntegrationHelper
  # Generates a signed JWT token for Plane integration with API details
  #
  # @param account_id [Integer] The account ID to encode in the token
  # @param api_url [String] The Plane API URL
  # @return [String, nil] The encoded JWT token or nil if client secret is missing
  def generate_plane_token(account_id, api_url)
    return if client_secret.blank?
    
    JWT.encode(plane_token_payload(account_id, api_url), client_secret, 'HS256')
  rescue StandardError => e
    Rails.logger.error("Failed to generate Plane token: #{e.message}")
    nil
  end

  def plane_token_payload(account_id, api_url)
    {
      sub: account_id,
      api_url: api_url,
      iat: Time.current.to_i,
      exp: Time.current.to_i + 1.hour.to_i # Token expires in 1 hour
    }
  end

  # Verifies and decodes a Plane JWT token
  #
  # @param token [String] The JWT token to verify
  # @return [Hash, nil] The decoded payload or nil if invalid
  def verify_plane_token(token)
    return if token.blank? || client_secret.blank?
    
    decoded = JWT.decode(token, client_secret, true, { algorithm: 'HS256' })
    decoded.first.with_indifferent_access
  rescue JWT::ExpiredSignature
    Rails.logger.warn('Plane token has expired')
    nil
  rescue JWT::DecodeError => e
    Rails.logger.error("Failed to decode Plane token: #{e.message}")
    nil
  end

  private

  def client_secret
    @client_secret ||= GlobalConfigService.load('SECRET_KEY_BASE', nil)
  end
end
