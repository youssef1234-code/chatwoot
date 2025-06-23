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

  def send_jira_completion_notifications(issue_key, issue_data)
    Rails.logger.info("JIRA Webhook: Sending completion notifications for issue #{issue_key}")

    # Find ALL conversations linked to this JIRA issue
    # This includes both direct JIRA links and ticket-based links
    conversations = find_all_conversations_for_issue(issue_key)

    if conversations.empty?
      Rails.logger.info("JIRA Webhook: No conversations found linked to issue #{issue_key}")
      return
    end

    # Extract issue details for the notification
    issue_summary = issue_data.dig('fields', 'summary') || 'Unknown'
    issue_assignee = issue_data.dig('fields', 'assignee', 'displayName') || issue_data.dig('fields', 'assignee', 'name')
    issue_reporter = issue_data.dig('fields', 'reporter', 'displayName') || issue_data.dig('fields', 'reporter', 'name')
    issue_url = build_jira_issue_url(issue_key, conversations.first.account)

    conversations.each do |conversation|
      send_completion_notification_to_conversation(
        conversation: conversation,
        issue_key: issue_key,
        issue_summary: issue_summary,
        issue_assignee: issue_assignee,
        issue_reporter: issue_reporter,
        issue_url: issue_url
      )
    end

    Rails.logger.info("JIRA Webhook: Sent completion notifications to #{conversations.count} conversations")
  end

  def find_all_conversations_for_issue(issue_key)
    conversations = []

    # Find conversations through direct JIRA issue links
    jira_links = JiraIssueLink.where(issue_key: issue_key).includes(:conversation)
    conversations += jira_links.map(&:conversation).compact

    # Find conversations through ticket links
    tickets = Ticket.where(jira_issue_key: issue_key).includes(:conversation)
    conversations += tickets.map(&:conversation).compact

    # Remove duplicates and return
    conversations.uniq
  end

  def send_completion_notification_to_conversation(conversation:, issue_key:, issue_summary:, issue_assignee:,
                                                   issue_reporter:, issue_url:)
    # Create a private message mentioning the issue creator/reporter
    mention_text = issue_reporter ? "@#{issue_reporter}" : 'Issue creator'

    message_content = "🎉 **JIRA Issue Completed**\n\n"
    message_content += "#{mention_text}, the JIRA issue [**#{issue_key}**](#{issue_url}) \"#{issue_summary}\" has been marked as completed.\n\n"

    message_content += "**Completed by:** #{issue_assignee}\n" if issue_assignee

    message_content += "**Issue:** #{issue_key}\n"
    message_content += '**Status:** Completed ✅'

    begin
      Messages::MessageBuilder.new(
        user: nil, # System message
        conversation: conversation,
        params: {
          content: message_content,
          message_type: :incoming,
          content_type: 'text',
          private: true, # This makes it a private message
          content_attributes: {
            jira_issue_key: issue_key,
            action_type: 'jira_issue_completed',
            mentioned_user: issue_reporter
          }
        }
      ).perform

      Rails.logger.info("JIRA Webhook: Sent completion notification to conversation #{conversation.id}")
    rescue StandardError => e
      Rails.logger.error("JIRA Webhook: Failed to send completion notification to conversation #{conversation.id}: #{e.message}")
    end
  end

  def build_jira_issue_url(issue_key, account)
    jira_hook = account.hooks.find_by(app_id: 'jira')
    base_url = jira_hook&.settings&.dig('site_url')

    if base_url
      "#{base_url}/browse/#{issue_key}"
    else
      '#' # Fallback if no JIRA URL configured
    end
  end

  def completed_status?(status)
    # Define which statuses indicate completion
    completion_statuses = %w[Done Resolved Closed Complete Completed]
    completion_statuses.any? { |completion_status| status.downcase.include?(completion_status.downcase) }
  end

  def update_issue_status_from_webhook(issue_key, new_status, account_id)
    Rails.logger.info("JIRA Webhook: Updating status for issue #{issue_key} to #{new_status}")

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

  def update_linked_tickets_on_jira_completion(issue_key, account_id)
    Rails.logger.info("JIRA Webhook: Updating tickets linked to completed JIRA issue #{issue_key}")

    # Find all tickets linked to this JIRA issue that aren't already resolved/closed
    tickets = Ticket.where(account_id: account_id, jira_issue_key: issue_key)
                    .where.not(status: %w[resolved closed])

    if tickets.empty?
      Rails.logger.info("JIRA Webhook: No active tickets found linked to issue #{issue_key}")
      return
    end

    tickets.each do |ticket|
      Rails.logger.info("JIRA Webhook: Resolving ticket ##{ticket.id} due to JIRA issue completion")

      begin
        # Use the ticket's resolve! method to ensure proper status handling
        ticket.update!(
          status: 'resolved',
          resolved_at: Time.current
        )

        # Create activity message in the conversation
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

    message_content = "🎉 **Ticket Automatically Resolved**\n\nTicket ##{ticket.id} \"#{ticket.title}\" has been automatically resolved because the linked JIRA issue **#{issue_key}** was marked as completed."

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
