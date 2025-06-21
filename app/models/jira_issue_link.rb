# == Schema Information
#
# Table name: jira_issue_links
#
#  id              :bigint           not null, primary key
#  issue_key       :string           not null
#  linked_at       :datetime         not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  account_id      :bigint           not null
#  comment_id      :string
#  conversation_id :bigint           not null
#  user_id         :bigint
#
# Indexes
#
#  index_jira_issue_links_on_account_id                     (account_id)
#  index_jira_issue_links_on_conversation_id                (conversation_id)
#  index_jira_issue_links_on_conversation_id_and_issue_key  (conversation_id,issue_key) UNIQUE
#  index_jira_issue_links_on_issue_key                      (issue_key)
#  index_jira_issue_links_on_user_id                        (user_id)
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

  def self.link_issue(conversation, issue_key, comment_id: nil, user: nil)
    create!(
      conversation: conversation,
      account: conversation.account,
      issue_key: issue_key,
      comment_id: comment_id,
      linked_at: Time.current,
      user: user
    )
  end

  def self.unlink_issue(conversation_id, issue_key)
    where(conversation_id: conversation_id, issue_key: issue_key).destroy_all
  end

  def self.linked_issues_for_conversation(conversation_id)
    where(conversation_id: conversation_id).pluck(:issue_key)
  end
end
