class Api::V1::Accounts::Contacts::ConversationsController < Api::V1::Accounts::Contacts::BaseController
  def index
    # Find conversations where this contact is the primary contact
    # OR where this contact has sent messages (participant in group conversations)
    sender_conversation_ids = Current.account.messages.reorder('')
                                     .where(sender_type: 'Contact', sender_id: @contact.id)
                                     .select(:conversation_id).distinct

    conversations = Current.account.conversations.includes(
      :assignee, :contact, :inbox, :taggings, :jira_issue_links, :plane_issue_links
    ).where(contact_id: @contact.id)
     .or(Current.account.conversations.where(id: sender_conversation_ids))

    # Apply permission-based filtering using the existing service
    conversations = Conversations::PermissionFilterService.new(
      conversations,
      Current.user,
      Current.account
    ).perform

    @conversations = conversations.order(last_activity_at: :desc).limit(20)
  end
end
