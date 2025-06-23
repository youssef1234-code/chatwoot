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
        
        # Find account by checking which accounts have this issue linked
        account = find_account_for_issue(issue_key)
        
        if account
          # Extract status information from webhook
          new_status = issue_data.dig('fields', 'status', 'name')
          
          # Process webhook if issue status is "Done" or other completion statuses
          if completed_status?(new_status)
            Jira::IssueCompletionNotificationJob.perform_later(
              issue_key: issue_key,
              issue_data: issue_data,
              account_id: account.id
            )
          else
            # For non-completion status changes, update status directly from webhook data
            update_issue_status_from_webhook(issue_key, new_status, account.id)
          end
        else
          Rails.logger.warn("JIRA Webhook: No account found with linked issue #{issue_key}")
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
    # Find the first account that has this issue linked
    link = JiraIssueLink.find_by(issue_key: issue_key)
    link&.account
  end

  def completed_status?(status)
    # Define which statuses indicate completion
    completion_statuses = ['Done', 'Resolved', 'Closed', 'Complete', 'Completed']
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
        
        # Broadcast the status update via websocket using the proper pattern
        broadcast_status_update(link.conversation, issue_key, new_status)
        
        Rails.logger.info("JIRA Webhook: Broadcasted status update for issue #{issue_key}")
      else
        Rails.logger.info("JIRA Webhook: No status change for link #{link.id} (already #{new_status})")
      end
    end

    # Update tickets linked to this JIRA issue when it's completed
    if completed_status?(new_status)
      update_linked_tickets_on_jira_completion(issue_key, account_id)
    end
  end

  def update_linked_tickets_on_jira_completion(issue_key, account_id)
    Rails.logger.info("JIRA Webhook: Updating tickets linked to completed JIRA issue #{issue_key}")
    
    # Find all tickets linked to this JIRA issue
    tickets = Ticket.where(account_id: account_id, jira_issue_key: issue_key)
                   .where.not(status: ['resolved', 'closed'])
    
    tickets.each do |ticket|
      Rails.logger.info("JIRA Webhook: Resolving ticket ##{ticket.id} due to JIRA issue completion")
      
      begin
        ticket.update!(
          status: 'resolved',
          resolved_at: Time.current
        )
        
        # Create activity message in the conversation
        create_jira_completion_activity_message(ticket, issue_key)
        
        Rails.logger.info("JIRA Webhook: Successfully resolved ticket ##{ticket.id}")
      rescue StandardError => e
        Rails.logger.error("JIRA Webhook: Failed to resolve ticket ##{ticket.id}: #{e.message}")
      end
    end
  end

  def create_jira_completion_activity_message(ticket, issue_key)
    return unless ticket.conversation

    message_content = "🎉 **Ticket Resolved**\n\nTicket ##{ticket.id} has been automatically resolved because the linked JIRA issue **#{issue_key}** was marked as completed."
    
    Messages::MessageBuilder.new(
      user: nil, # System message
      conversation: ticket.conversation,
      params: {
        content: message_content,
        message_type: :activity,
        content_type: 'text',
        content_attributes: {
          automation_rule_id: nil,
          automation_rule_name: 'JIRA Integration'
        }
      }
    ).perform
  rescue StandardError => e
    Rails.logger.error("JIRA Webhook: Failed to create activity message for ticket ##{ticket.id}: #{e.message}")
  end

  def broadcast_status_update(conversation, issue_key, new_status)
    # Get tokens for all users who have access to this specific conversation
    tokens = user_tokens_for_conversation(conversation)
    
    broadcast_data = {
      conversation_id: conversation.id,
      issue_key: issue_key,
      new_status: new_status,
      issue_status: new_status, # Also include as issue_status for frontend compatibility
      account_id: conversation.account_id
    }
    
    Rails.logger.info("JIRA Webhook: Broadcasting status update to #{tokens.length} users for conversation #{conversation.id}")
    ActionCableBroadcastJob.perform_later(tokens, 'jira_issue_status_updated', broadcast_data)
  end

  def user_tokens_for_conversation(conversation)
    # Get tokens for all users who have access to this conversation
    inbox_members = conversation.inbox.inbox_members.includes(:user)
    account_admins = conversation.account.administrators
    
    users = (inbox_members.map(&:user) + account_admins).uniq
    users.map(&:pubsub_token)
  end
end
