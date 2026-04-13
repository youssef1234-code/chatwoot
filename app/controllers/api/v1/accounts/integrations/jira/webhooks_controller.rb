class Api::V1::Accounts::Integrations::Jira::WebhooksController < Api::V1::Accounts::BaseController
  skip_before_action :authenticate_user!, only: [:create]
  skip_before_action :set_current_user, only: [:create]
  before_action :verify_webhook_source, only: [:create]

  def index
    render json: { message: 'JIRA webhook endpoint is active' }
  end

  def create
    Rails.logger.info("JIRA Webhook: Received webhook data: #{request.raw_post}")

    begin
      webhook_data = JSON.parse(request.raw_post)

      # Extract relevant information from JIRA webhook
      webhook_event = webhook_data['webhookEvent']
      issue_data = webhook_data['issue']

      Rails.logger.info("JIRA Webhook: Event type: #{webhook_event}")

      if webhook_event == 'jira:issue_updated' && issue_data.present?
        issue_key = issue_data['key']
        issue_status = issue_data['fields']['status']['name']

        Rails.logger.info("JIRA Webhook: Issue #{issue_key} status changed to #{issue_status}")

        # Extract status information from webhook
        new_status = issue_data.dig('fields', 'status', 'name')

        Rails.logger.info("JIRA Webhook: Processing status change to #{new_status} for issue #{issue_key}")

        # ALWAYS process JIRA issue completion notifications (private messages)
        # regardless of whether there are linked tickets
        if completed_status?(new_status)
          # Send completion notification to all linked conversations
          send_jira_completion_notifications(issue_key, issue_data)
        end

        # Find account by checking which accounts have this issue linked (for ticket updates)
        account = find_account_for_issue(issue_key)

        if account
          # Update the JIRA issue status in our system
          update_issue_status_from_webhook(issue_key, new_status, account.id)

          # Update any linked tickets
          update_linked_tickets_on_jira_completion(issue_key, account.id) if completed_status?(new_status)
        else
          Rails.logger.info("JIRA Webhook: No tickets linked to issue #{issue_key}, but completion notifications may still be sent")
        end
      elsif webhook_event == 'jira:issue_deleted' && issue_data.present?
        handle_issue_deleted(issue_data['key'])
      end

      render json: { status: 'success', message: 'Webhook processed successfully' }
    rescue JSON::ParserError => e
      Rails.logger.error("JIRA Webhook: Invalid JSON received: #{e.message}")
      render json: { error: 'Invalid JSON format' }, status: :bad_request
    rescue StandardError => e
      Rails.logger.error("JIRA Webhook: Error processing webhook: #{e.message}")
      render json: { error: 'Internal server error' }, status: :internal_server_error
    end
  end

  private

  def verify_webhook_source
    # Basic verification - in production, you might want to implement JIRA webhook signatures
    # For now, we'll allow all requests but log them for monitoring
    Rails.logger.info("JIRA Webhook: Request from IP: #{request.remote_ip}")
    Rails.logger.info("JIRA Webhook: User Agent: #{request.user_agent}")
  end

  def find_account_for_issue(issue_key)
    # Find the first account that has this issue linked (either via tickets or direct JIRA links)
    ticket_link = Ticket.joins(:account).find_by(jira_issue_key: issue_key)&.account
    jira_link = JiraIssueLink.find_by(issue_key: issue_key)&.account

    ticket_link || jira_link
  end

  def handle_issue_deleted(issue_key)
    return if issue_key.blank?

    Rails.logger.info("JIRA Webhook: Issue #{issue_key} was deleted from JIRA")

    # Find all links for this issue across all accounts
    links = JiraIssueLink.where(issue_key: issue_key).includes(:conversation, :account)

    if links.empty?
      Rails.logger.info("JIRA Webhook: No links found for deleted issue #{issue_key}")
      return
    end

    links.each do |link|
      conversation = link.conversation
      next unless conversation

      # Create an activity message informing about the deletion
      begin
        conversation.messages.create!(
          content: "⚠️ **JIRA Issue Deleted**\n\nThe linked JIRA issue **#{issue_key}** has been deleted from JIRA. The link has been automatically removed.",
          message_type: :activity,
          private: true,
          sender: nil,
          account: link.account,
          inbox: conversation.inbox,
          content_type: 'text'
        )
      rescue StandardError => e
        Rails.logger.error("JIRA Webhook: Failed to create deletion activity message: #{e.message}")
      end

      # Broadcast update so frontend refreshes
      begin
        tokens = user_tokens_for_conversation(conversation)
        ActionCableBroadcastJob.perform_later(
          tokens,
          'jira_issue_deleted',
          { conversation_id: conversation.id, issue_key: issue_key, account_id: link.account_id }
        )
      rescue StandardError => e
        Rails.logger.error("JIRA Webhook: Failed to broadcast deletion event: #{e.message}")
      end
    end

    # Remove all links for this issue
    count = links.destroy_all.length
    Rails.logger.info("JIRA Webhook: Removed #{count} links for deleted issue #{issue_key}")

    # Also clear the jira_issue_key on any tickets
    Ticket.where(jira_issue_key: issue_key).update_all(jira_issue_key: nil, jira_status: nil, jira_in_progress: false)
  end

  def find_accounts_for_issue(issue_key)
    # Find ALL accounts that have this issue linked (either via tickets or direct JIRA links)
    accounts = []

    # From tickets
    ticket_accounts = Account.joins(:tickets).where(tickets: { jira_issue_key: issue_key })
    accounts += ticket_accounts.to_a

    # From JIRA issue links
    jira_accounts = Account.joins(:jira_issue_links).where(jira_issue_links: { issue_key: issue_key })
    accounts += jira_accounts.to_a

    accounts.uniq
  end

  def send_jira_completion_notifications(issue_key, issue_data)
    Rails.logger.info("JIRA Webhook: Sending completion notifications for issue #{issue_key}")

    # Find all accounts that have this issue linked
    accounts = find_accounts_for_issue(issue_key)

    if accounts.empty?
      Rails.logger.info("JIRA Webhook: No accounts found with linked issue #{issue_key}")
      return
    end

    # Use the job to handle completion notifications for each account
    accounts.each do |account|
      Jira::IssueCompletionNotificationJob.perform_later(
        issue_key: issue_key,
        issue_data: issue_data,
        account_id: account.id
      )
    end

    Rails.logger.info("JIRA Webhook: Queued completion notification jobs for #{accounts.count} accounts")
  end

  def completed_status?(status)
    # Use configurable final statuses from the integration settings
    # Fall back to defaults if no configuration found
    account = find_account_for_issue_from_context
    if account
      processor = Integrations::Jira::ProcessorService.new(account: account)
      return processor.completed_status?(status)
    end

    # Default completion statuses as fallback
    default_completion_statuses = %w[Done Resolved Closed Complete Completed Canceled Solved]
    default_completion_statuses.any? { |completion_status| status.downcase.include?(completion_status.downcase) }
  end

  def find_account_for_issue_from_context
    # Try to find account from the current route params or from the webhook data
    Account.find_by(id: params[:account_id])
  end

  def update_issue_status_from_webhook(issue_key, new_status, account_id)
    Rails.logger.info("JIRA Webhook: Updating status for issue #{issue_key} to #{new_status}")

    # Update tickets linked to this JIRA issue
    update_linked_tickets_jira_status(issue_key, new_status, account_id)

    # Find all links for this issue in this account with eager loading
    issue_links = JiraIssueLink.for_issue(issue_key)
                               .where(account_id: account_id)
                               .includes(:conversation, :account)

    issue_links.each do |link|
      if link.status_changed?(new_status)
        Rails.logger.info("JIRA Webhook: Status changed for link #{link.id} from #{link.last_known_status} to #{new_status}")

        # Update the status
        link.update_status!(new_status)

        # Broadcast the status update via websocket
        broadcast_jira_status_update(link.conversation, issue_key, new_status)

        Rails.logger.info("JIRA Webhook: Broadcasted status update for issue #{issue_key}")
      else
        Rails.logger.info("JIRA Webhook: No status change for link #{link.id} (already #{new_status})")
      end
    end
  end

  def update_linked_tickets_jira_status(issue_key, new_status, account_id)
    Rails.logger.info("JIRA Webhook: Updating tickets linked to JIRA issue #{issue_key} with status #{new_status}")

    # Find all tickets linked to this JIRA issue
    tickets = Ticket.where(account_id: account_id, jira_issue_key: issue_key)

    if tickets.empty?
      Rails.logger.info("JIRA Webhook: No tickets found linked to issue #{issue_key}")
      return
    end

    tickets.each do |ticket|
      Rails.logger.info("JIRA Webhook: Updating ticket ##{ticket.id} JIRA status to #{new_status}")

      begin
        # Determine if the new status indicates "In Progress"
        in_progress = in_progress_status?(new_status)

        # Update the ticket's JIRA status and in_progress flag
        ticket.update!(
          jira_status: new_status,
          jira_in_progress: in_progress
        )

        # Broadcast ticket update to websockets for real-time UI updates
        broadcast_ticket_update_for_jira_status(ticket)

        Rails.logger.info("JIRA Webhook: Successfully updated ticket ##{ticket.id} - jira_in_progress: #{in_progress}")
      rescue StandardError => e
        Rails.logger.error("JIRA Webhook: Failed to update ticket ##{ticket.id}: #{e.message}")
      end
    end

    Rails.logger.info("JIRA Webhook: Completed updating #{tickets.count} tickets for issue #{issue_key}")
  end

  def in_progress_status?(status)
    # Define which statuses indicate "In Progress"
    in_progress_statuses = ['in progress', 'in-progress', 'doing', 'active', 'working', 'development', 'dev']
    in_progress_statuses.any? { |in_progress_status| status.downcase.include?(in_progress_status.downcase) }
  end

  def update_linked_tickets_on_jira_completion(issue_key, account_id)
    Rails.logger.info("JIRA Webhook: Updating tickets linked to completed JIRA issue #{issue_key}")

    # Find all tickets linked to this JIRA issue
    tickets = Ticket.where(account_id: account_id, jira_issue_key: issue_key)

    if tickets.empty?
      Rails.logger.info("JIRA Webhook: No active tickets found linked to issue #{issue_key}")
      return
    end

    tickets.each do |ticket|
      Rails.logger.info("JIRA Webhook: Resolving ticket ##{ticket.id} due to JIRA issue completion")

      begin
        # Only create activity message to notify about JIRA completion, but don't auto-resolve ticket
        create_jira_completion_activity_message(ticket, issue_key)

        # Broadcast ticket update to websockets
        broadcast_ticket_update(ticket)

        Rails.logger.info("JIRA Webhook: Successfully resolved ticket ##{ticket.id}")
      rescue StandardError => e
        Rails.logger.error("JIRA Webhook: Failed to resolve ticket ##{ticket.id}: #{e.message}")
      end
    end

    Rails.logger.info("JIRA Webhook: Completed processing #{tickets.count} tickets for issue #{issue_key}")
  end

  def create_jira_completion_activity_message(ticket, issue_key)
    return unless ticket.conversation

    message_content = "🎉 **JIRA Issue Completed**\n\nThe linked JIRA issue **#{issue_key}** has been marked as completed. Ticket ##{ticket.id} \"#{ticket.title}\" remains open and requires manual resolution."

    Messages::MessageBuilder.new(
      user: nil, # System message
      conversation: ticket.conversation,
      params: {
        content: message_content,
        message_type: :activity,
        content_type: 'text',
        private: false,
        content_attributes: {
          ticket_id: ticket.id,
          jira_issue_key: issue_key,
          action_type: 'jira_auto_resolved'
        }
      }
    ).perform
  rescue StandardError => e
    Rails.logger.error("JIRA Webhook: Failed to create activity message for ticket ##{ticket.id}: #{e.message}")
  end

  def broadcast_ticket_update(ticket)
    # Broadcast ticket update to all users with access to the conversation
    tokens = user_tokens_for_conversation(ticket.conversation)

    broadcast_data = {
      ticket_id: ticket.id,
      status: ticket.status,
      resolved_at: ticket.resolved_at,
      conversation_id: ticket.conversation_id,
      account_id: ticket.account_id,
      jira_issue_key: ticket.jira_issue_key
    }

    Rails.logger.info("JIRA Webhook: Broadcasting ticket update for ticket ##{ticket.id}")
    ActionCableBroadcastJob.perform_later(tokens, 'ticket_updated', broadcast_data)

    # Also broadcast JIRA completion event for real-time UI updates
    if ticket.jira_issue_key.present?
      broadcast_jira_status_update(ticket.conversation, ticket.jira_issue_key, 'completed')
    end
  rescue StandardError => e
    Rails.logger.error("JIRA Webhook: Failed to broadcast ticket update for ticket ##{ticket.id}: #{e.message}")
  end

  def broadcast_ticket_update_for_jira_status(ticket)
    # Broadcast ticket update for JIRA status changes to account channel for real-time UI updates
    Rails.logger.info("JIRA Webhook: Broadcasting ticket JIRA status update for ticket ##{ticket.id}")

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
      jira_issue_key: ticket.jira_issue_key,
      jira_status: ticket.jira_status,
      jira_in_progress: ticket.jira_in_progress?
    }

    # Broadcast to the account channel for real-time updates
    ActionCable.server.broadcast(
      "account_#{ticket.account_id}",
      {
        event: 'ticket_updated',
        data: broadcast_data
      }
    )

    Rails.logger.info("JIRA Webhook: Broadcasted ticket JIRA status update to account_#{ticket.account_id}")
  rescue StandardError => e
    Rails.logger.error("JIRA Webhook: Failed to broadcast ticket JIRA status update for ticket ##{ticket.id}: #{e.message}")
  end

  def broadcast_jira_status_update(conversation, issue_key, new_status)
    # Get tokens for all users who have access to this specific conversation
    tokens = user_tokens_for_conversation(conversation)

    broadcast_data = {
      conversation_id: conversation.id,
      issue_key: issue_key,
      new_status: new_status,
      issue_status: new_status, # Also include as issue_status for frontend compatibility
      account_id: conversation.account_id,
      completed: completed_status?(new_status)
    }

    Rails.logger.info("JIRA Webhook: Broadcasting JIRA status update to #{tokens.length} users for conversation #{conversation.id}")
    ActionCableBroadcastJob.perform_later(tokens, 'jira_issue_status_updated', broadcast_data)
  rescue StandardError => e
    Rails.logger.error("JIRA Webhook: Failed to broadcast JIRA status update: #{e.message}")
  end

  def broadcast_status_update(conversation, issue_key, new_status)
    # Legacy method - redirect to the new enhanced method
    broadcast_jira_status_update(conversation, issue_key, new_status)
  end

  def user_tokens_for_conversation(conversation)
    # Get tokens for all users who have access to this conversation
    inbox_members = conversation.inbox.inbox_members.includes(:user)
    account_admins = conversation.account.administrators

    users = (inbox_members.map(&:user) + account_admins).uniq
    users.map(&:pubsub_token)
  end
end
