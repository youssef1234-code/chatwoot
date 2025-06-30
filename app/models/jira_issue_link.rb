# == Schema Information
#
# Table name: jira_issue_links
#
#  id                            :bigint           not null, primary key
#  issue_key                     :string           not null
#  last_known_status             :string
#  last_status_check_at          :datetime
#  linked_at                     :datetime         not null
#  webhook_notifications_enabled :boolean          default(TRUE)
#  created_at                    :datetime         not null
#  updated_at                    :datetime         not null
#  account_id                    :bigint           not null
#  comment_id                    :string
#  conversation_id               :bigint           not null
#  user_id                       :bigint
#
# Indexes
#
#  index_jira_issue_links_on_account_id                     (account_id)
#  index_jira_issue_links_on_conversation_id                (conversation_id)
#  index_jira_issue_links_on_conversation_id_and_issue_key  (conversation_id,issue_key) UNIQUE
#  index_jira_issue_links_on_issue_key                      (issue_key)
#  index_jira_issue_links_on_last_status_check_at           (last_status_check_at)
#  index_jira_issue_links_on_user_id                        (user_id)
#  index_jira_issue_links_on_webhook_notifications_enabled  (webhook_notifications_enabled)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (conversation_id => conversations.id)
#  fk_rails_...  (user_id => users.id)
#
class JiraIssueLink < ApplicationRecord
  belongs_to :conversation
  belongs_to :account
  belongs_to :user, optional: true

  validates :issue_key, presence: true
  validates :linked_at, presence: true
  validates :conversation_id, uniqueness: { scope: :issue_key, message: "Issue already linked to this conversation" }

  scope :for_conversation, ->(conversation_id) { where(conversation_id: conversation_id) }
  scope :for_account, ->(account_id) { where(account_id: account_id) }
  scope :for_issue, ->(issue_key) { where(issue_key: issue_key) }
  scope :with_notifications_enabled, -> { where(webhook_notifications_enabled: true) }
  scope :stale_status_check, -> { where('last_status_check_at IS NULL OR last_status_check_at < ?', 30.minutes.ago) }

  def self.link_issue(conversation, issue_key, comment_id: nil, user: nil)
    create!(
      conversation: conversation,
      account: conversation.account,
      issue_key: issue_key,
      comment_id: comment_id,
      linked_at: Time.current,
      user: user,
      webhook_notifications_enabled: true
    )
  end

  def self.unlink_issue(conversation_id, issue_key)
    # Check if this issue is linked to any tickets
    tickets_with_issue = Ticket.where(jira_issue_key: issue_key)
    
    if tickets_with_issue.exists?
      # If the issue is linked to tickets, prevent unlinking
      raise StandardError, "Cannot unlink JIRA issue #{issue_key} as it is linked to #{tickets_with_issue.count} ticket(s). Please remove the JIRA link from the ticket(s) first."
    end
    
    # Only unlink if no tickets are associated with this issue
    where(conversation_id: conversation_id, issue_key: issue_key).destroy_all
  end

  def self.linked_issues_for_conversation(conversation_id)
    where(conversation_id: conversation_id).pluck(:issue_key)
  end

  def update_status!(new_status)
    update!(
      last_known_status: new_status,
      last_status_check_at: Time.current
    )
  end

  def status_changed?(new_status)
    last_known_status != new_status
  end

  def completed_status?(status = last_known_status)
    return false if status.blank?
    
    completion_statuses = ['Done', 'Resolved', 'Closed', 'Complete', 'Completed']
    completion_statuses.any? { |completion_status| status.downcase.include?(completion_status.downcase) }
  end

  def needs_status_check?
    last_status_check_at.nil? || last_status_check_at < 30.minutes.ago
  end
end
