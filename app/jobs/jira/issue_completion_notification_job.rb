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
      
      next unless conversation
      next unless link.webhook_notifications_enabled?
      
      # Get ALL inbox users for this conversation's inbox (not just linking agents)
      all_inbox_users = get_all_inbox_users(conversation)
      
      # Create a private automated message in the conversation
      create_completion_message(conversation, all_inbox_users, issue_key, issue_data)
      
      # Broadcast real-time update to agents
      broadcast_issue_update(conversation, issue_key, issue_data)
      
      # Disable further notifications for this link to avoid spam
      link.update!(webhook_notifications_enabled: false)
    end
  end

  private

  def get_all_linking_agents(conversation)
    # Get all unique users who have linked JIRA issues to this conversation
    jira_agents = JiraIssueLink.where(conversation: conversation)
                               .where.not(user_id: nil)
                               .includes(:user)
                               .map(&:user)
                               .compact
                               .uniq
    
    # Also include agents who linked Plane issues (if that integration exists)
    plane_agents = if defined?(PlaneIssueLink)
                     PlaneIssueLink.where(conversation: conversation)
                                   .where.not(user_id: nil)
                                   .includes(:user)
                                   .map(&:user)
                                   .compact
                                   .uniq
                   else
                     []
                   end
    
    # Also include the assigned agent if any
    assigned_agent = conversation.assignee
    
    # Combine all and return unique
    (jira_agents + plane_agents + [assigned_agent].compact).uniq
  end

  # Get ALL users who are members of the conversation's inbox
  def get_all_inbox_users(conversation)
    inbox = conversation.inbox
    return [] unless inbox

    # Get all inbox members (agents assigned to this inbox)
    inbox_members = inbox.inbox_members.includes(:user).map(&:user).compact

    # Also include the assigned agent and linking agents
    linking_agents = get_all_linking_agents(conversation)

    # Include account administrators
    account_admins = conversation.account.administrators.to_a

    # Combine all users: inbox members + linking agents + account admins
    all_users = (inbox_members + linking_agents + account_admins).uniq

    Rails.logger.info("JIRA: Notifying #{all_users.count} inbox users for completion (#{inbox_members.count} inbox members, #{linking_agents.count} linking agents, #{account_admins.count} admins)")
    all_users
  end

  def create_completion_message(conversation, all_agents, issue_key, issue_data)
    issue_summary = issue_data.dig('fields', 'summary') || 'JIRA Issue'
    issue_status = issue_data.dig('fields', 'status', 'name') || 'Done'
    
    # Create automated private message
    message_content = build_completion_message_content(issue_key, issue_summary, issue_status, all_agents)
    
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

  def build_completion_message_content(issue_key, issue_summary, issue_status, all_agents)
    # Create proper Chatwoot mention format for ALL agents
    agent_mentions = if all_agents.any?
                       all_agents.map do |agent|
                         "[#{agent.name}](mention://user/#{agent.id}/#{agent.name.gsub(' ', '%20')})"
                       end.join(', ')
                     else
                       "the team"
                     end
    
    <<~MESSAGE
      🎉 **JIRA Issue Completed**
      
      The JIRA issue **#{issue_key}: #{issue_summary}** has been marked as **#{issue_status}**.
      
      Hey #{agent_mentions} - this issue linked to this conversation has been completed.
      
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
