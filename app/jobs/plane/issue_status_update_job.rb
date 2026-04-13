class Plane::IssueStatusUpdateJob < ApplicationJob
  queue_as :medium

  def perform(issue_id:, project_id:, account_id:)
    Rails.logger.info("Plane: Polling for status update of issue #{issue_id} in project #{project_id}")

    account = Account.find(account_id)

    # Get Plane configuration for this account
    plane_hook = account.hooks.find_by(app_id: 'plane')
    return unless plane_hook&.enabled?

    # Find all links for this issue in this account
    issue_links = PlaneIssueLink.for_issue(issue_id).where(account: account)
    return if issue_links.empty?

    # Fetch current issue state from Plane
    begin
      plane_processor = Integrations::Plane::ProcessorService.new(hook: plane_hook, account: account)
      issue_response = plane_processor.get_issue(project_id, issue_id)

      if issue_response.is_a?(Hash) && (issue_response[:error] || issue_response['error'])
        Rails.logger.error("Plane: Failed to fetch issue #{issue_id}: #{issue_response[:error] || issue_response['error']}")
        return
      end

      issue_data = issue_response.is_a?(Hash) && issue_response[:data] ? issue_response[:data] : issue_response
      current_state = issue_data.dig('state_detail', 'name') || issue_data['state_name']
      issue_key = issue_links.first.issue_key

      Rails.logger.info("Plane: Issue #{issue_key} current state: #{current_state}")

      # Check if state has changed for any of the links
      state_changed = false
      issue_links.each do |link|
        if link.state_changed?(current_state)
          state_changed = true
          Rails.logger.info("Plane: State changed for issue #{issue_key} from '#{link.last_known_state}' to '#{current_state}'")

          # Update the link with new state
          link.update_state!(current_state)

          # Check if issue is now completed
          if link.completed_state?(current_state)
            Rails.logger.info("Plane: Issue #{issue_key} is now completed")

            Plane::IssueCompletionNotificationJob.perform_later(
              issue_id: issue_id,
              issue_data: {
                'name' => issue_data['name'],
                'state_name' => current_state
              },
              account_id: account_id,
              conversation_id: link.conversation.id
            )
          end
        else
          # Still update the last check time even if state hasn't changed
          link.update!(last_state_check_at: Time.current)
        end
      end

      # Broadcast state update to frontend if state changed
      if state_changed
        broadcast_state_update(issue_key, issue_id, project_id, issue_data, current_state, account)
      end
    rescue StandardError => e
      Rails.logger.error("Plane: Error polling issue #{issue_id}: #{e.message}")
    end
  end

  private

  def broadcast_state_update(issue_key, issue_id, project_id, issue_data, current_state, account)
    # Extract state_color from issue data (state_detail or state object)
    state_color = issue_data.dig('state_detail', 'color') || issue_data.dig('state', 'color')

    # Find all conversations linked to this issue
    linked_conversations = PlaneIssueLink.for_issue(issue_id)
                                         .includes(:conversation)
                                         .where(account: account)

    linked_conversations.each do |link|
      conversation = link.conversation
      next unless conversation

      tokens = user_tokens_for_conversation(conversation)

      broadcast_data = {
        conversation_id: conversation.id,
        issue_key: issue_key,
        issue_id: issue_id,
        project_id: project_id,
        state_name: current_state,
        state_color: state_color,
        name: issue_data['name'],
        account_id: account.id
      }

      ActionCableBroadcastJob.perform_later(tokens, 'plane_issue_state_updated', broadcast_data)
    end
  end

  def user_tokens_for_conversation(conversation)
    inbox_members = conversation.inbox.inbox_members.includes(:user)
    account_admins = conversation.account.administrators

    users = (inbox_members.map(&:user) + account_admins).uniq
    users.map(&:pubsub_token)
  end
end
