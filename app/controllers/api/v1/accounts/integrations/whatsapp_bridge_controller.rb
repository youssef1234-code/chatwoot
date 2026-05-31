class Api::V1::Accounts::Integrations::WhatsappBridgeController < Api::V1::Accounts::BaseController
  before_action :fetch_hook

  DEFAULT_BRIDGE_URL = 'http://localhost:3100'.freeze

  # GET settings (connection + numbers + team members)
  def get_settings
    render json: settings_payload, status: :ok
  end

  # PATCH connection settings (bridge_url, sync_number, continue_number)
  def update_settings
    permitted = params.permit(:bridge_url, :sync_number, :continue_number)
    merged = @hook.settings.merge(permitted.to_h.reject { |_k, v| v.nil? })
    merged['bridge_url'] = merged['bridge_url'].to_s.chomp('/') if merged['bridge_url'].present?
    @hook.update!(settings: merged)
    render json: settings_payload, status: :ok
  end

  # GET team members (Chatwoot is source of truth; bridge is kept in sync)
  def team_members
    render json: { team_members: stored_members }, status: :ok
  end

  # POST add/update a team member
  def upsert_team_member
    phone = normalize_phone(params[:phone_number])
    role = params[:role].to_s
    display_name = params[:display_name].presence
    return render json: { error: 'phone_number and role are required' }, status: :unprocessable_entity if phone.blank? || role.blank?

    members = stored_members.reject { |m| m['phone_number'] == phone }
    members << { 'phone_number' => phone, 'role' => role, 'display_name' => display_name }.compact
    persist_members(members)
    push_member_to_bridge(phone, role, display_name)

    render json: { team_members: members }, status: :ok
  end

  # DELETE a team member by phone
  def delete_team_member
    phone = normalize_phone(params[:phone_number])
    members = stored_members.reject { |m| m['phone_number'] == phone }
    persist_members(members)
    delete_member_from_bridge(phone)
    render json: { team_members: members }, status: :ok
  end

  # GET bridge session status (ready + whether a QR is pending)
  def session_status
    response = HTTParty.get("#{bridge_url}/session/status", timeout: 5)
    body = response.parsed_response || {}
    render json: {
      ready: body['ready'],
      qr_pending: body['latestQr'].present?,
      qr_image: body['latestQrImage'],
      reachable: true
    }, status: :ok
  rescue StandardError => e
    Rails.logger.warn("WhatsAppBridge: status check failed: #{e.message}")
    render json: { ready: false, qr_pending: false, qr_image: nil, reachable: false }, status: :ok
  end

  # POST switch from the sync number to the continue number
  def switch_session
    HTTParty.post("#{bridge_url}/session/switch", timeout: 10)
    render json: { status: 'switching' }, status: :ok
  rescue StandardError => e
    render json: { error: "Bridge not reachable: #{e.message}" }, status: :unprocessable_entity
  end

  # POST restart linking — force a fresh QR (re-resolves the web version)
  def restart_session
    HTTParty.post("#{bridge_url}/session/restart", timeout: 10)
    render json: { status: 'restarting' }, status: :ok
  rescue StandardError => e
    render json: { error: "Bridge not reachable: #{e.message}" }, status: :unprocessable_entity
  end

  private

  def fetch_hook
    @hook = Current.account.hooks.find_by(app_id: 'whatsapp_bridge')
    render json: { error: 'WhatsApp Bridge integration not configured' }, status: :not_found if @hook.blank?
  end

  def settings_payload
    {
      bridge_url: bridge_url,
      sync_number: @hook.settings['sync_number'],
      continue_number: @hook.settings['continue_number'],
      team_members: stored_members
    }
  end

  def stored_members
    @hook.settings['team_members'].is_a?(Array) ? @hook.settings['team_members'] : []
  end

  def persist_members(members)
    @hook.update!(settings: @hook.settings.merge('team_members' => members))
  end

  def bridge_url
    (@hook.settings['bridge_url'].presence || DEFAULT_BRIDGE_URL).chomp('/')
  end

  def normalize_phone(value)
    value.to_s.gsub(/\s/, '')
  end

  # Best-effort sync to the bridge's existing /team-members endpoint.
  # Never fails the request if the bridge is unreachable (e.g. local dev).
  def push_member_to_bridge(phone, role, display_name)
    HTTParty.post("#{bridge_url}/team-members",
                  body: { phone_number: phone, role: role, display_name: display_name }.to_json,
                  headers: { 'Content-Type' => 'application/json' }, timeout: 5)
  rescue StandardError => e
    Rails.logger.warn("WhatsAppBridge: could not push member to bridge: #{e.message}")
  end

  def delete_member_from_bridge(phone)
    HTTParty.delete("#{bridge_url}/team-members/#{CGI.escape(phone)}", timeout: 5)
  rescue StandardError => e
    Rails.logger.warn("WhatsAppBridge: could not delete member on bridge: #{e.message}")
  end
end
