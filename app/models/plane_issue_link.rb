# == Schema Information
#
# Table name: plane_issue_links
#
#  id                            :bigint           not null, primary key
#  issue_key                     :string           not null
#  last_known_state              :string
#  last_state_check_at           :datetime
#  linked_at                     :datetime         not null
#  webhook_notifications_enabled :boolean          default(TRUE)
#  created_at                    :datetime         not null
#  updated_at                    :datetime         not null
#  account_id                    :bigint           not null
#  conversation_id               :bigint           not null
#  issue_id                      :string           not null
#  link_id                       :string
#  project_id                    :string           not null
#  user_id                       :bigint
#
# Indexes
#
#  index_plane_issue_links_on_account_id                     (account_id)
#  index_plane_issue_links_on_conversation_id                (conversation_id)
#  index_plane_issue_links_on_conversation_id_and_issue_id   (conversation_id,issue_id) UNIQUE
#  index_plane_issue_links_on_issue_id                       (issue_id)
#  index_plane_issue_links_on_issue_key                      (issue_key)
#  index_plane_issue_links_on_last_state_check_at            (last_state_check_at)
#  index_plane_issue_links_on_project_id                     (project_id)
#  index_plane_issue_links_on_user_id                        (user_id)
#  index_plane_issue_links_on_webhook_notifications_enabled  (webhook_notifications_enabled)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (conversation_id => conversations.id)
#  fk_rails_...  (user_id => users.id)
#
class PlaneIssueLink < ApplicationRecord
  belongs_to :conversation
  belongs_to :account
  belongs_to :user, optional: true

  validates :issue_id, presence: true
  validates :issue_key, presence: true
  validates :project_id, presence: true
  validates :linked_at, presence: true
  validates :conversation_id, uniqueness: { scope: :issue_id, message: "Issue already linked to this conversation" }

  scope :for_conversation, ->(conversation_id) { where(conversation_id: conversation_id) }
  scope :for_account, ->(account_id) { where(account_id: account_id) }
  scope :for_issue, ->(issue_id) { where(issue_id: issue_id) }
  scope :for_project, ->(project_id) { where(project_id: project_id) }
  scope :with_notifications_enabled, -> { where(webhook_notifications_enabled: true) }
  scope :stale_state_check, -> { where('last_state_check_at IS NULL OR last_state_check_at < ?', 30.minutes.ago) }

  def self.link_issue(conversation, project_id, issue_id, issue_key, link_id: nil, user: nil)
    create!(
      conversation: conversation,
      account: conversation.account,
      project_id: project_id,
      issue_id: issue_id,
      issue_key: issue_key,
      link_id: link_id,
      linked_at: Time.current,
      user: user,
      webhook_notifications_enabled: true
    )
  end

  def self.unlink_issue(conversation_id, issue_id)
    where(conversation_id: conversation_id, issue_id: issue_id).destroy_all
  end

  def self.linked_issues_for_conversation(conversation_id)
    where(conversation_id: conversation_id).pluck(:issue_id, :project_id)
  end

  def update_state!(new_state)
    attrs = {
      last_known_state: new_state,
      last_state_check_at: Time.current
    }
    # Re-enable notifications when transitioning away from a completion state
    # so that if the issue goes Done → In Progress → Done again, we notify again
    attrs[:webhook_notifications_enabled] = true unless completed_state?(new_state)
    update!(attrs)
  end

  def state_changed?(new_state)
    last_known_state != new_state
  end

  def completed_state?(state = last_known_state)
    return false if state.blank?

    hook = account&.hooks&.find_by(app_id: 'plane')
    configured_states = hook&.settings&.dig('done_statuses')
    completion_states = configured_states.present? ? configured_states : ['Done', 'Completed', 'Closed', 'Cancelled']
    completion_states.any? { |completion_state| state.downcase.strip == completion_state.downcase.strip }
  end

  def needs_state_check?
    last_state_check_at.nil? || last_state_check_at < 30.minutes.ago
  end
end
