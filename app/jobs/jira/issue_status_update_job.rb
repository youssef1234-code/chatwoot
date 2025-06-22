class Jira::IssueStatusUpdateJob < ApplicationJob
  queue_as :medium

  def perform(issue_key:, account_id:)
    Rails.logger.info("JIRA: Polling for status update of issue #{issue_key}")
    
    account = Account.find(account_id)
    
    # Get JIRA configuration for this account
    jira_hook = account.hooks.find_by(app_id: 'jira')
    return unless jira_hook&.enabled?
    
    # Find all links for this issue in this account
    issue_links = JiraIssueLink.for_issue(issue_key).where(account: account)
    return if issue_links.empty?
    
    # Fetch current issue status from JIRA
    begin
      jira_processor = Integrations::Jira::ProcessorService.new(hook: jira_hook, account: account)
      issue_response = jira_processor.get_issue(issue_key)
      
      if issue_response[:error]
        Rails.logger.error("JIRA: Failed to fetch issue #{issue_key}: #{issue_response[:error]}")
        return
      end
      
      issue_data = issue_response[:data]
      current_status = issue_data['status']
      
      Rails.logger.info("JIRA: Issue #{issue_key} current status: #{current_status}")
      
      # Check if status has changed for any of the links
      status_changed = false
      issue_links.each do |link|
        if link.status_changed?(current_status)
          status_changed = true
          Rails.logger.info("JIRA: Status changed for issue #{issue_key} from '#{link.last_known_status}' to '#{current_status}'")
          
          # Update the link with new status
          link.update_status!(current_status)
          
          # Check if issue is now completed
          if link.completed_status?(current_status)
            Rails.logger.info("JIRA: Issue #{issue_key} is now completed")
            
            # Trigger completion notification for this specific conversation
            Jira::IssueCompletionNotificationJob.perform_later(
              issue_key: issue_key,
              issue_data: {
                'key' => issue_key,
                'fields' => {
                  'summary' => issue_data['summary'],
                  'status' => { 'name' => current_status }
                }
              },
              account_id: account_id,
              conversation_id: link.conversation.id
            )
          end
        else
          # Still update the last check time even if status hasn't changed
          link.update!(last_status_check_at: Time.current)
        end
      end
      
      # Broadcast status update to frontend if status changed
      if status_changed
        broadcast_status_update(issue_key, issue_data, account)
      end
      
    rescue StandardError => e
      Rails.logger.error("JIRA: Error polling issue #{issue_key}: #{e.message}")
    end
  end

  private

  def broadcast_status_update(issue_key, issue_data, account)
    # Find all conversations linked to this issue
    linked_conversations = JiraIssueLink.for_issue(issue_key)
                                      .includes(:conversation)
                                      .where(account: account)
    
    linked_conversations.each do |link|
      conversation = link.conversation
      next unless conversation
      
      tokens = user_tokens_for_conversation(conversation)
      
      broadcast_data = {
        conversation_id: conversation.id,
        issue_key: issue_key,
        issue_status: issue_data['status'],
        issue_summary: issue_data['summary'],
        account_id: account.id
      }
      
      ActionCableBroadcastJob.perform_later(tokens, 'jira_issue_status_updated', broadcast_data)
    end
  end

  def user_tokens_for_conversation(conversation)
    inbox_members = conversation.inbox.inbox_members.includes(:user)
    account_admins = conversation.account.administrators
    
    users = (inbox_members.map(&:user) + account_admins).uniq
    users.map(&:pubsub_token)
  end
end
