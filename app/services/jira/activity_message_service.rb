class Jira::ActivityMessageService
  include Rails.application.routes.url_helpers

  pattr_initialize [:conversation!, :action_type!, :issue_data!, :user!]

  def perform
    create_activity_message
  end

  private

  def create_activity_message
    content = case action_type
              when :issue_created
                "JIRA issue #{issue_data[:key]} was created by #{user.name}"
              when :issue_linked
                "JIRA issue #{issue_data[:key]} was linked by #{user.name}"
              when :issue_unlinked
                "JIRA issue #{issue_data[:key]} was unlinked by #{user.name}"
              else
                "JIRA action performed by #{user.name}"
              end

    Conversations::ActivityMessageJob.perform_later(
      conversation,
      {
        account_id: conversation.account_id,
        inbox_id: conversation.inbox_id,
        message_type: :activity,
        content: content
      }
    )
  end
end
