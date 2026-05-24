class Conversations::PermissionFilterService
  attr_reader :conversations, :user, :account

  def initialize(conversations, user, account)
    @conversations = conversations
    @user = user
    @account = account
  end

  def perform
    # Administrators see everything unless they have an optional channel allow-list.
    return conversations if user_role == 'administrator' && !admin_inbox_restricted?

    accessible_conversations
  end

  private

  def admin_inbox_restricted?
    account_user&.inbox_access_restricted?
  end

  def accessible_conversations
    conversations.where(inbox_id: accessible_inbox_ids)
  end

  # Channel-restricted admins use their allow-list; everyone else uses inbox membership.
  def accessible_inbox_ids
    return account_user.cleaned_allowed_inbox_ids if admin_inbox_restricted?

    user.inboxes.where(account_id: account.id).select(:id)
  end

  def account_user
    AccountUser.find_by(account_id: account.id, user_id: user.id)
  end

  def user_role
    account_user&.role
  end
end

Conversations::PermissionFilterService.prepend_mod_with('Conversations::PermissionFilterService')
