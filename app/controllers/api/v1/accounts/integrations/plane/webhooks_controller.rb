class Api::V1::Accounts::Integrations::Plane::WebhooksController < Api::V1::Accounts::BaseController
  skip_before_action :authenticate_user!, only: [:create], raise: false
  skip_before_action :set_current_user, only: [:create], raise: false
  before_action :verify_webhook_source, only: [:create]

  def index
    render json: { message: 'Plane webhook endpoint is active' }
  end

  def create
    Rails.logger.info("Plane Webhook: Received webhook data: #{request.raw_post}")

    begin
      webhook_data = JSON.parse(request.raw_post)

      # Plane webhook structure - event can be "issue.updated" or separate "event"+"action" fields
      raw_event = webhook_data['event']
      action = webhook_data['action']
      issue_data = webhook_data['data']

      # Normalize event type: Plane may send "issue" + "created" or "issue.created" directly
      event_type = if action.present? && !raw_event.include?('.')
                     "#{raw_event}.#{action}"
                   else
                     raw_event
                   end

      Rails.logger.info("Plane Webhook: Event type: #{event_type} (raw: #{raw_event}, action: #{action})")

      case event_type
      when 'issue.updated'
        handle_issue_updated(issue_data, webhook_data)
      when 'issue.deleted'
        handle_issue_deleted(issue_data)
      when 'issue_comment.created'
        handle_comment_created(webhook_data)
      end

      render json: { status: 'success', message: 'Webhook processed successfully' }
    rescue JSON::ParserError => e
      Rails.logger.error("Plane Webhook: Invalid JSON received: #{e.message}")
      render json: { error: 'Invalid JSON format' }, status: :bad_request
    rescue StandardError => e
      Rails.logger.error("Plane Webhook: Error processing webhook: #{e.message}")
      render json: { error: 'Internal server error' }, status: :internal_server_error
    end
  end

  private

  def verify_webhook_source
    Rails.logger.info("Plane Webhook: Request from IP: #{request.remote_ip}")
    Rails.logger.info("Plane Webhook: User Agent: #{request.user_agent}")
    
    # Verify webhook secret if configured (from integration hook settings, fallback to ENV)
    # Current.account is nil in webhook context (auth skipped), so check ENV first
    webhook_secret = ENV.fetch('PLANE_WEBHOOK_SECRET', nil)
    
    # If no ENV secret, try to find from any Plane hook (webhook verification is global)
    if webhook_secret.blank?
      hook = Integrations::Hook.find_by(app_id: 'plane')
      webhook_secret = hook&.settings&.dig('webhook_secret')
    end
    
    return unless webhook_secret.present?
    
    provided_signature = request.headers['X-Plane-Signature']
    if provided_signature.blank?
      Rails.logger.warn("Plane Webhook: Missing signature header")
      return
    end
    
    expected_signature = OpenSSL::HMAC.hexdigest('SHA256', webhook_secret, request.raw_post)
    unless ActiveSupport::SecurityUtils.secure_compare(expected_signature, provided_signature)
      Rails.logger.warn("Plane Webhook: Invalid signature")
      render json: { error: 'Invalid signature' }, status: :unauthorized
    end
  end

  def handle_issue_updated(issue_data, webhook_data)
    issue_id = issue_data['id']
    project_id = issue_data['project']
    
    Rails.logger.info("Plane Webhook: Issue #{issue_id} updated")

    # Extract state information from webhook payload
    # Plane sends state as an OBJECT: {"id": "...", "name": "Done", "color": "#16A34A", "group": "completed"}
    # NOT as state_detail or a UUID string
    state_data = issue_data['state']
    new_state = nil
    state_color = nil

    if state_data.is_a?(Hash)
      # Plane webhook embeds the full state object under 'state'
      new_state = state_data['name']
      state_color = state_data['color']
      Rails.logger.info("Plane Webhook: Extracted state from object: #{new_state} (color: #{state_color}, group: #{state_data['group']})")
    elsif state_data.is_a?(String) && state_data.present?
      # Fallback: state is a UUID string, resolve via Plane API
      account = find_account_for_issue(issue_id)
      if account
        begin
          processor = Integrations::Plane::ProcessorService.new(account: account)
          new_state = processor.send(:determine_state_name, project_id, state_data)
          new_state = nil if new_state == 'Unknown'

          if state_color.blank?
            states = processor.send(:plane_client).get_project_states(project_id)
            unless states.is_a?(Hash) && states[:error]
              state_obj = states.find { |s| s['id'] == state_data }
              state_color = state_obj&.dig('color')
            end
          end

          Rails.logger.info("Plane Webhook: Resolved state from UUID: #{new_state} (color: #{state_color})")
        rescue StandardError => e
          Rails.logger.warn("Plane Webhook: Could not resolve state from UUID: #{e.message}")
        end
      end
    end

    # Also try state_detail (some Plane versions) and changed_fields as fallbacks
    new_state ||= issue_data.dig('state_detail', 'name')
    state_color ||= issue_data.dig('state_detail', 'color')

    # Always broadcast update for issue data changes (name, etc.) even without state change
    account ||= find_account_for_issue(issue_id)
    # Cache account for use by completed_state? and broadcast methods within this request
    @_cached_account = account

    if account && new_state.present?
      Rails.logger.info("Plane Webhook: Processing state change to #{new_state} for issue #{issue_id}")

      # Check if this is a completion state
      if completed_state?(new_state, account)
        # Inject resolved state info into issue_data for the notification job
        enriched_data = issue_data.merge('resolved_state_name' => new_state, 'resolved_state_color' => state_color)
        send_plane_completion_notifications(issue_id, enriched_data)
      end

      # Update the Plane issue state in our system
      update_issue_state_from_webhook(issue_id, new_state, state_color, account.id)

      # Update any linked tickets
      update_linked_tickets_on_plane_completion(issue_id, account.id) if completed_state?(new_state, account)
    elsif account
      # Non-state change (name, description, etc.) — still broadcast refresh
      broadcast_plane_refresh_for_issue(issue_id, account)
    else
      Rails.logger.info("Plane Webhook: No accounts linked to issue #{issue_id}")
    end
  end

  def handle_issue_deleted(issue_data)
    issue_id = issue_data['id']
    
    Rails.logger.info("Plane Webhook: Issue #{issue_id} deleted")
    
    # Clean up links to deleted issues
    PlaneIssueLink.where(issue_id: issue_id).destroy_all
  end

  def handle_comment_created(webhook_data)
    comment_data = webhook_data['data']
    issue_id = comment_data['issue']
    
    Rails.logger.info("Plane Webhook: New comment on issue #{issue_id}")
    
    # Optionally notify conversations about new comments
    # This could be implemented to sync comments back to Chatwoot
  end

  def find_account_for_issue(issue_id)
    # Find the first account that has this issue linked
    ticket_link = Ticket.joins(:account).find_by(plane_issue_id: issue_id)&.account
    plane_link = PlaneIssueLink.find_by(issue_id: issue_id)&.account

    ticket_link || plane_link
  end

  def find_accounts_for_issue(issue_id)
    accounts = []

    # From tickets
    ticket_accounts = Account.joins(:tickets).where(tickets: { plane_issue_id: issue_id })
    accounts += ticket_accounts.to_a

    # From Plane issue links
    plane_accounts = Account.joins(:plane_issue_links).where(plane_issue_links: { issue_id: issue_id })
    accounts += plane_accounts.to_a

    accounts.uniq
  end

  def send_plane_completion_notifications(issue_id, issue_data)
    Rails.logger.info("Plane Webhook: Sending completion notifications for issue #{issue_id}")

    accounts = find_accounts_for_issue(issue_id)

    if accounts.empty?
      Rails.logger.info("Plane Webhook: No accounts found with linked issue #{issue_id}")
      return
    end

    accounts.each do |account|
      Plane::IssueCompletionNotificationJob.perform_later(
        issue_id: issue_id,
        issue_data: issue_data,
        account_id: account.id
      )
    end

    Rails.logger.info("Plane Webhook: Queued completion notification jobs for #{accounts.count} accounts")
  end

  def completed_state?(state, account = nil)
    account ||= find_account_for_issue_cached
    hook = account&.hooks&.find_by(app_id: 'plane')
    configured_states = hook&.settings&.dig('done_statuses')
    completion_states = configured_states.present? ? configured_states : %w[Done Completed Closed Cancelled]
    completion_states.any? { |completion_state| state.to_s.downcase.strip == completion_state.downcase.strip }
  end

  # Cache the account lookup within a single request to avoid repeated DB queries
  def find_account_for_issue_cached
    @_cached_account ||= nil
  end

  def update_issue_state_from_webhook(issue_id, new_state, state_color, account_id)
    Rails.logger.info("Plane Webhook: Updating state for issue #{issue_id} to #{new_state}")

    # Update tickets linked to this Plane issue
    update_linked_tickets_plane_state(issue_id, new_state, account_id)

    # Find all links for this issue in this account
    issue_links = PlaneIssueLink.for_issue(issue_id)
                               .where(account_id: account_id)
                               .includes(:conversation, :account)

    issue_links.each do |link|
      if link.state_changed?(new_state)
        Rails.logger.info("Plane Webhook: State changed for link #{link.id} from #{link.last_known_state} to #{new_state}")

        link.update_state!(new_state)
        broadcast_plane_state_update(link.conversation, link.issue_key, new_state, link.issue_id, state_color)

        Rails.logger.info("Plane Webhook: Broadcasted state update for issue #{link.issue_key}")
      else
        Rails.logger.info("Plane Webhook: No state change for link #{link.id} (already #{new_state})")
      end
    end
  end

  def update_linked_tickets_plane_state(issue_id, new_state, account_id)
    Rails.logger.info("Plane Webhook: Updating tickets linked to Plane issue #{issue_id} with state #{new_state}")

    tickets = Ticket.where(account_id: account_id, plane_issue_id: issue_id)

    if tickets.empty?
      Rails.logger.info("Plane Webhook: No tickets found linked to issue #{issue_id}")
      return
    end

    tickets.each do |ticket|
      Rails.logger.info("Plane Webhook: Updating ticket ##{ticket.id} Plane state to #{new_state}")

      begin
        in_progress = in_progress_state?(new_state)

        ticket.update!(
          plane_state: new_state,
          plane_in_progress: in_progress
        )

        broadcast_ticket_update_for_plane_state(ticket)

        Rails.logger.info("Plane Webhook: Successfully updated ticket ##{ticket.id} - plane_in_progress: #{in_progress}")
      rescue StandardError => e
        Rails.logger.error("Plane Webhook: Failed to update ticket ##{ticket.id}: #{e.message}")
      end
    end
  end

  def in_progress_state?(state)
    in_progress_states = ['in progress', 'in-progress', 'doing', 'active', 'working', 'started']
    in_progress_states.any? { |in_progress_state| state.to_s.downcase.include?(in_progress_state.downcase) }
  end

  def update_linked_tickets_on_plane_completion(issue_id, account_id)
    Rails.logger.info("Plane Webhook: Updating tickets linked to completed Plane issue #{issue_id}")

    tickets = Ticket.where(account_id: account_id, plane_issue_id: issue_id)

    if tickets.empty?
      Rails.logger.info("Plane Webhook: No active tickets found linked to issue #{issue_id}")
      return
    end

    tickets.each do |ticket|
      Rails.logger.info("Plane Webhook: Processing ticket ##{ticket.id} due to Plane issue completion")

      begin
        # Don't create a separate completion message here — IssueCompletionNotificationJob
        # already creates one with @mentions for the same conversation.
        broadcast_ticket_update(ticket)

        Rails.logger.info("Plane Webhook: Successfully processed ticket ##{ticket.id}")
      rescue StandardError => e
        Rails.logger.error("Plane Webhook: Failed to process ticket ##{ticket.id}: #{e.message}")
      end
    end
  end

  def create_plane_completion_activity_message(ticket, issue_id)
    return unless ticket.conversation

    issue_key = ticket.plane_issue_key || issue_id
    message_content = "🎉 **Plane Issue Completed**\n\nThe linked Plane issue **#{issue_key}** has been marked as completed. Ticket ##{ticket.id} \"#{ticket.title}\" remains open and requires manual resolution."

    Messages::MessageBuilder.new(
      user: nil,
      conversation: ticket.conversation,
      params: {
        content: message_content,
        message_type: :activity,
        content_type: 'text',
        private: false,
        content_attributes: {
          ticket_id: ticket.id,
          plane_issue_id: issue_id,
          action_type: 'plane_auto_resolved'
        }
      }
    ).perform
  rescue StandardError => e
    Rails.logger.error("Plane Webhook: Failed to create activity message for ticket ##{ticket.id}: #{e.message}")
  end

  def broadcast_ticket_update(ticket)
    tokens = user_tokens_for_conversation(ticket.conversation)

    broadcast_data = {
      ticket_id: ticket.id,
      status: ticket.status,
      resolved_at: ticket.resolved_at,
      conversation_id: ticket.conversation_id,
      account_id: ticket.account_id,
      plane_issue_id: ticket.plane_issue_id
    }

    Rails.logger.info("Plane Webhook: Broadcasting ticket update for ticket ##{ticket.id}")
    ActionCableBroadcastJob.perform_later(tokens, 'ticket_updated', broadcast_data)

    if ticket.plane_issue_id.present?
      broadcast_plane_state_update(ticket.conversation, ticket.plane_issue_key, 'completed', ticket.plane_issue_id)
    end
  rescue StandardError => e
    Rails.logger.error("Plane Webhook: Failed to broadcast ticket update for ticket ##{ticket.id}: #{e.message}")
  end

  def broadcast_ticket_update_for_plane_state(ticket)
    Rails.logger.info("Plane Webhook: Broadcasting ticket Plane state update for ticket ##{ticket.id}")

    broadcast_data = {
      id: ticket.id,
      title: ticket.title,
      description: ticket.description,
      status: ticket.status,
      priority: ticket.priority,
      conversation_id: ticket.conversation_id,
      account_id: ticket.account_id,
      conversation: {
        id: ticket.conversation.id,
        display_id: ticket.conversation.display_id,
        status: ticket.conversation.status
      },
      contact: ticket.contact,
      assigned_agent: ticket.assigned_agent,
      created_by: ticket.created_by,
      created_at: ticket.created_at,
      updated_at: ticket.updated_at,
      plane_issue_id: ticket.plane_issue_id,
      plane_issue_key: ticket.plane_issue_key,
      plane_state: ticket.plane_state,
      plane_in_progress: ticket.plane_in_progress?
    }

    ActionCable.server.broadcast(
      "account_#{ticket.account_id}",
      {
        event: 'ticket_updated',
        data: broadcast_data
      }
    )

    Rails.logger.info("Plane Webhook: Broadcasted ticket Plane state update to account_#{ticket.account_id}")
  rescue StandardError => e
    Rails.logger.error("Plane Webhook: Failed to broadcast ticket Plane state update for ticket ##{ticket.id}: #{e.message}")
  end

  def broadcast_plane_state_update(conversation, issue_key, new_state, issue_id = nil, state_color = nil)
    tokens = user_tokens_for_conversation(conversation)

    broadcast_data = {
      conversation_id: conversation.id,
      issue_id: issue_id,
      issue_key: issue_key,
      state_name: new_state,
      new_state: new_state,
      issue_state: new_state,
      state_color: state_color,
      account_id: conversation.account_id,
      completed: completed_state?(new_state, conversation.account)
    }

    Rails.logger.info("Plane Webhook: Broadcasting Plane state update to #{tokens.length} users for conversation #{conversation.id}")
    ActionCableBroadcastJob.perform_later(tokens, 'plane_issue_state_updated', broadcast_data)
  rescue StandardError => e
    Rails.logger.error("Plane Webhook: Failed to broadcast Plane state update: #{e.message}")
  end

  def broadcast_plane_refresh_for_issue(issue_id, account)
    issue_links = PlaneIssueLink.for_issue(issue_id)
                               .where(account_id: account.id)
                               .includes(:conversation)

    issue_links.each do |link|
      next unless link.conversation

      tokens = user_tokens_for_conversation(link.conversation)
      broadcast_data = {
        conversation_id: link.conversation.id,
        issue_id: issue_id,
        issue_key: link.issue_key,
        account_id: account.id,
        refresh: true
      }
      ActionCableBroadcastJob.perform_later(tokens, 'plane_issue_state_updated', broadcast_data)
    end
  rescue StandardError => e
    Rails.logger.error("Plane Webhook: Failed to broadcast refresh for issue #{issue_id}: #{e.message}")
  end

  def user_tokens_for_conversation(conversation)
    inbox_members = conversation.inbox.inbox_members.includes(:user)
    account_admins = conversation.inbox.administrators_with_access

    users = (inbox_members.map(&:user) + account_admins).uniq
    users.map(&:pubsub_token)
  end
end
