class Plane::IssueCompletionNotificationJob < ApplicationJob
  queue_as :high

  def perform(issue_id:, issue_data:, account_id:, conversation_id: nil)
    Rails.logger.info("Plane: Processing completion notification for issue #{issue_id}")
    
    @account = Account.find(account_id)
    @hook = @account.hooks.find_by(app_id: 'plane')
    
    # Find conversations linked to this issue
    linked_conversations = if conversation_id
                             PlaneIssueLink.for_issue(issue_id)
                                        .includes(:conversation, :user)
                                        .where(account: @account, conversation_id: conversation_id)
                           else
                             PlaneIssueLink.for_issue(issue_id)
                                        .includes(:conversation, :user)
                                        .where(account: @account)
                           end
    
    return if linked_conversations.empty?
    
    Rails.logger.info("Plane: Found #{linked_conversations.count} conversations linked to issue #{issue_id}")
    
    linked_conversations.each do |link|
      conversation = link.conversation
      next unless conversation
      next unless link.webhook_notifications_enabled?
      
      # Get ALL users involved in the conversation (agents, admins, assignee, linkers)
      all_agents = get_all_conversation_agents(conversation)
      
      # Create a completion message mentioning all agents
      create_completion_message(conversation, all_agents, link.issue_key, issue_data)
      
      # Auto-resolve the conversation if enabled in settings
      auto_resolve_conversation(conversation) if should_auto_resolve?
      
      # Broadcast real-time update to agents
      broadcast_issue_update(conversation, link.issue_key, issue_data)
      
      # Disable further notifications for this link to avoid spam
      link.update!(webhook_notifications_enabled: false)
    end
  end

  private

  def should_auto_resolve?
    settings = @hook&.settings || {}
    settings.fetch('auto_resolve_conversation', true)
  end

  def auto_resolve_conversation(conversation)
    return if conversation.resolved?

    Rails.logger.info("Plane: Auto-resolving conversation #{conversation.id} due to Plane issue completion")
    
    conversation.update!(status: :resolved)
    
    Rails.configuration.dispatcher.dispatch(
      Events::Types::CONVERSATION_RESOLVED,
      Time.zone.now,
      conversation: conversation
    )
  rescue StandardError => e
    Rails.logger.error("Plane: Failed to auto-resolve conversation #{conversation.id}: #{e.message}")
  end

  def mention_config
    settings = @hook&.settings || {}
    settings['mention_config'] || {
      'issue_creator' => true,
      'assignee' => true,
      'participating_agents' => true,
      'inbox_members' => false,
      'static_emails' => []
    }
  end

  def get_all_conversation_agents(conversation)
    config = mention_config
    agents = Set.new

    # Issue creator (agent who linked the Plane issue)
    if config['issue_creator'] != false
      PlaneIssueLink.where(conversation: conversation)
                     .where.not(user_id: nil)
                     .includes(:user)
                     .each { |link| agents << link.user if link.user }
    end

    # Assigned agent
    if config['assignee'] != false
      agents << conversation.assignee if conversation.assignee
    end

    # All participating agents (who sent messages in this conversation)
    if config['participating_agents'] != false
      conversation.messages
                  .where(message_type: :outgoing)
                  .where.not(sender_id: nil)
                  .where(sender_type: 'User')
                  .includes(:sender)
                  .each { |msg| agents << msg.sender if msg.sender }
    end

    # Inbox members (agents assigned to this inbox)
    if config['inbox_members'] == true
      conversation.inbox.inbox_members.includes(:user).each do |member|
        agents << member.user if member.user
      end
    end

    # Static email list — find users by email and add them
    static_emails = Array(config['static_emails'])
    if static_emails.any?
      static_users = @account.users.where(email: static_emails)
      static_users.each { |u| agents << u }
    end

    agents.to_a.compact.uniq
  end

  def create_completion_message(conversation, all_agents, issue_key, issue_data)
    issue_name = issue_data['name'] || issue_data.dig('fields', 'name') || 'Plane Issue'
    issue_state = issue_data['resolved_state_name'] || issue_data.dig('state_detail', 'name') || 'Done'
    
    message_content = build_completion_message_content(issue_key, issue_name, issue_state, all_agents)
    
    message = conversation.messages.create!(
      content: message_content,
      message_type: :activity,
      private: true,
      sender: nil,
      account: conversation.account,
      inbox: conversation.inbox,
      content_type: 'text',
      content_attributes: {
        automation_rule: {
          id: 'plane_completion_notification',
          name: 'Plane Issue Completion Notification'
        }
      }
    )
    
    Rails.logger.info("Plane: Created completion notification message in conversation #{conversation.id}")
    
    Rails.configuration.dispatcher.dispatch(
      Events::Types::MESSAGE_CREATED,
      Time.zone.now,
      message: message
    )
  end

  def build_completion_message_content(issue_key, issue_name, issue_state, all_agents)
    # Create proper Chatwoot mention format for ALL agents
    agent_mentions = if all_agents.any?
                       all_agents.map do |agent|
                         "[#{agent.name}](mention://user/#{agent.id}/#{agent.name.gsub(' ', '%20')})"
                       end.join(', ')
                     else
                       "the team"
                     end

    resolve_note = should_auto_resolve? ? "\n\nThis conversation has been automatically resolved." : ""
    
    <<~MESSAGE
      🎉 **Plane Issue Completed**
      
      The Plane issue **#{issue_key}: #{issue_name}** has been marked as **#{issue_state}**.
      
      Hey #{agent_mentions} — this issue linked to this conversation is now done.#{resolve_note}
    MESSAGE
  end

  def broadcast_issue_update(conversation, issue_key, issue_data)
    tokens = user_tokens_for_conversation(conversation)
    
    broadcast_data = {
      conversation_id: conversation.id,
      issue_key: issue_key,
      issue_state: issue_data['resolved_state_name'] || issue_data.dig('state_detail', 'name') || 'Done',
      completed: true,
      account_id: conversation.account_id
    }
    
    ActionCableBroadcastJob.perform_later(tokens, 'plane_issue_state_updated', broadcast_data)
  rescue StandardError => e
    Rails.logger.error("Plane: Failed to broadcast issue update: #{e.message}")
  end

  def user_tokens_for_conversation(conversation)
    inbox_members = conversation.inbox.inbox_members.includes(:user)
    account_admins = conversation.account.administrators

    users = (inbox_members.map(&:user) + account_admins).uniq
    users.map(&:pubsub_token)
  end
end
