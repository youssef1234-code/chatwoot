class Plane::ActivityMessageService
  pattr_initialize [:conversation!, :action_type!, :issue_data!, :user]

  ACTION_MESSAGES = {
    issue_created: 'created and linked a new Plane issue',
    issue_linked: 'linked a Plane issue',
    issue_unlinked: 'unlinked a Plane issue'
  }.freeze

  def perform
    create_activity_message
  end

  private

  def create_activity_message
    message_content = build_message_content
    
    conversation.messages.create!(
      content: message_content,
      message_type: :activity,
      private: true,
      sender: user,
      account: conversation.account,
      inbox: conversation.inbox,
      content_type: 'text',
      content_attributes: {
        plane_activity: {
          action_type: action_type,
          issue_key: issue_data[:key],
          issue_url: issue_data[:url],
          issue_title: issue_data[:title]
        }.compact
      }
    )
  rescue StandardError => e
    Rails.logger.error("Plane::ActivityMessageService error: #{e.message}")
    nil
  end

  def build_message_content
    action_text = ACTION_MESSAGES[action_type] || 'performed an action on a Plane issue'
    agent_name = user&.name || 'System'
    
    issue_link = if issue_data[:url].present?
                   "[#{issue_data[:key]}](#{issue_data[:url]})"
                 else
                   issue_data[:key]
                 end
    
    case action_type
    when :issue_created
      "✅ **#{agent_name}** #{action_text}: #{issue_link}"
    when :issue_linked
      "🔗 **#{agent_name}** #{action_text}: #{issue_link}"
    when :issue_unlinked
      "🔓 **#{agent_name}** #{action_text}: #{issue_data[:key]}"
    else
      "📝 **#{agent_name}** #{action_text}"
    end
  end
end
