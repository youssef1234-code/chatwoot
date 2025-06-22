class Jira::IssueCompletionNotificationJob < ApplicationJob
  queue_as :high

  def perform(issue_key:, issue_data:, account_id:, conversation_id: nil)
    Rails.logger.info("JIRA: Processing completion notification for issue #{issue_key}")
    
    account = Account.find(account_id)
    
    # Find conversations linked to this issue
    linked_conversations = if conversation_id
                             # If specific conversation is provided, only process that one
                             JiraIssueLink.for_issue(issue_key)
                                        .includes(:conversation, :user)
                                        .where(account: account, conversation_id: conversation_id)
                           else
                             # Process all linked conversations
                             JiraIssueLink.for_issue(issue_key)
                                        .includes(:conversation, :user)
                                        .where(account: account)
                           end
    
    return if linked_conversations.empty?
    
    Rails.logger.info("JIRA: Found #{linked_conversations.count} conversations linked to issue #{issue_key}")
    
    linked_conversations.each do |link|
      conversation = link.conversation
      linking_agent = link.user
      
      next unless conversation && linking_agent
      next unless link.webhook_notifications_enabled?
      
      # Create a private automated message in the conversation
      create_completion_message(conversation, linking_agent, issue_key, issue_data)
      
      # Broadcast real-time update to agents
      broadcast_issue_update(conversation, issue_key, issue_data)
      
      # Disable further notifications for this link to avoid spam
      link.update!(webhook_notifications_enabled: false)
    end
  end

  private

  def create_completion_message(conversation, linking_agent, issue_key, issue_data)
    issue_summary = issue_data.dig('fields', 'summary') || 'JIRA Issue'
    issue_status = issue_data.dig('fields', 'status', 'name') || 'Done'
    
    # Create automated private message
    message_content = build_completion_message_content(issue_key, issue_summary, issue_status, linking_agent)
    
    # Use the system bot account or create as a private message from the system
    message = conversation.messages.create!(
      content: message_content,
      message_type: :activity,
      private: true,
      sender: nil, # System message
      account: conversation.account,
      inbox: conversation.inbox, # Required field
      content_type: 'text',
      content_attributes: {
        automation_rule: {
          id: 'jira_completion_notification',
          name: 'JIRA Issue Completion Notification'
        }
      }
    )
    
    Rails.logger.info("JIRA: Created completion notification message in conversation #{conversation.id}")
    
    # Dispatch message creation event for real-time updates
    Rails.configuration.dispatcher.dispatch(
      Events::Types::MESSAGE_CREATED,
      Time.zone.now,
      message: message
    )
  end

  def build_completion_message_content(issue_key, issue_summary, issue_status, linking_agent)
    # Create proper Chatwoot mention format
    agent_mention = "[#{linking_agent.name}](mention://user/#{linking_agent.id}/#{linking_agent.name.gsub(' ', '%20')})"
    
    <<~MESSAGE
      🎉 **JIRA Issue Completed**
      
      The JIRA issue **#{issue_key}: #{issue_summary}** has been marked as **#{issue_status}**.
      
      This issue was linked to this conversation by #{agent_mention}.
      
      The development work associated with this conversation has been completed. You may want to follow up with the customer to confirm the resolution.
    MESSAGE
  end

  def broadcast_issue_update(conversation, issue_key, issue_data)
    # Broadcast to conversation participants about the issue completion
    tokens = user_tokens_for_conversation(conversation)
    
    broadcast_data = {
      conversation_id: conversation.id,
      issue_key: issue_key,
      issue_status: issue_data.dig('fields', 'status', 'name'),
      issue_summary: issue_data.dig('fields', 'summary'),
      account_id: conversation.account_id
    }
    
    ActionCableBroadcastJob.perform_later(tokens, 'jira_issue_completed', broadcast_data)
  end

  def user_tokens_for_conversation(conversation)
    # Get tokens for all users who have access to this conversation
    inbox_members = conversation.inbox.inbox_members.includes(:user)
    account_admins = conversation.account.administrators
    
    users = (inbox_members.map(&:user) + account_admins).uniq
    users.map(&:pubsub_token)
  end
end
