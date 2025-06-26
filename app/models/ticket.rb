# == Schema Information
#
# Table name: tickets
#
#  id                :bigint           not null, primary key
#  category          :string
#  description       :text
#  issue_type        :string
#  jira_in_progress  :boolean
#  jira_issue_key    :string
#  jira_status       :string
#  priority          :integer          default("medium"), not null
#  resolved_at       :datetime
#  status            :integer          default("open"), not null
#  title             :string           not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  account_id        :bigint           not null
#  assigned_agent_id :bigint
#  contact_id        :bigint
#  conversation_id   :bigint           not null
#  created_by_id     :bigint           not null
#
# Indexes
#
#  index_tickets_on_account_id         (account_id)
#  index_tickets_on_assigned_agent_id  (assigned_agent_id)
#  index_tickets_on_category           (category)
#  index_tickets_on_contact_id         (contact_id)
#  index_tickets_on_conversation_id    (conversation_id)
#  index_tickets_on_created_by_id      (created_by_id)
#  index_tickets_on_jira_issue_key     (jira_issue_key)
#  index_tickets_on_priority           (priority)
#  index_tickets_on_status             (status)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (assigned_agent_id => users.id)
#  fk_rails_...  (contact_id => contacts.id)
#  fk_rails_...  (conversation_id => conversations.id)
#  fk_rails_...  (created_by_id => users.id)
#

class Ticket < ApplicationRecord
  belongs_to :account
  belongs_to :conversation
  belongs_to :contact, optional: true
  belongs_to :created_by, class_name: 'User'
  belongs_to :assigned_agent, class_name: 'User', optional: true

  has_many :ticket_messages, dependent: :destroy
  has_one :jira_issue_link, foreign_key: :conversation_id, primary_key: :conversation_id

  validates :title, presence: true, length: { maximum: 255 }
  validates :description, length: { maximum: 5000 }
  validates :status, presence: true
  validates :priority, presence: true
  validate :category_must_be_valid

  enum status: {
    open: 0,
    in_progress: 1,
    escalated: 2,
    resolved: 3,
    closed: 4
  }

  enum priority: {
    low: 0,
    medium: 1,
    high: 2,
    urgent: 3
  }

  scope :for_account, ->(account_id) { where(account_id: account_id) }
  scope :for_conversation, ->(conversation_id) { where(conversation_id: conversation_id) }
  scope :by_status, ->(status) { where(status: status) }
  scope :by_priority, ->(priority) { where(priority: priority) }
  scope :by_category, ->(category) { where(category: category) }
  scope :created_by, ->(user_id) { where(created_by_id: user_id) }
  scope :assigned_to, ->(user_id) { where(assigned_agent_id: user_id) }
  scope :with_jira_link, -> { joins(:jira_issue_link) }
  scope :without_jira_link, -> { left_joins(:jira_issue_link).where(jira_issue_links: { id: nil }) }

  before_save :set_resolved_at

  def escalate_to_jira!(jira_issue_key)
    update!(
      status: :escalated,
      jira_issue_key: jira_issue_key
    )
  end

  def escalate!
    update!(status: :escalated)
  end

  def resolve!
    update!(
      status: :resolved,
      resolved_at: Time.current
    )
  end

  def close!
    update!(
      status: :closed,
      resolved_at: resolved_at || Time.current
    )
  end

  def escalated_to_jira?
    jira_issue_key.present? || jira_issue_link.present?
  end

  def jira_url
    return nil unless jira_issue_key.present?

    jira_hook = account.hooks.find_by(app_id: 'jira')
    return nil unless jira_hook&.settings&.dig('site_url')

    "#{jira_hook.settings['site_url']}/browse/#{jira_issue_key}"
  end

  def jira_in_progress?
    # First check if we have a stored jira_in_progress flag (from webhook updates)
    return read_attribute(:jira_in_progress) if has_attribute?(:jira_in_progress) && !read_attribute(:jira_in_progress).nil?
    
    # Fallback to checking jira_status if no stored flag
    return false unless jira_status.present?

    # Common JIRA status values that indicate work in progress
    in_progress_statuses = [
      'in progress', 'in-progress', 'doing', 'active', 'working', 'development', 'dev'
    ]

    in_progress_statuses.any? { |status| jira_status.downcase.include?(status) }
  end

  def jira_status
    # First check if we have a stored jira_status (from webhook updates)
    stored_status = read_attribute(:jira_status)
    return stored_status if stored_status.present?
    
    # Fallback to jira_issue_link status
    jira_issue_link&.last_known_status
  end

  def can_be_escalated?
    !escalated_to_jira? && (open? || in_progress?)
  end

  def duration_to_resolve
    return nil unless resolved_at.present?

    resolved_at - created_at
  end

  private

  def set_resolved_at
    if status_changed? && (resolved? || closed?)
      self.resolved_at = Time.current if resolved_at.nil?
    elsif status_changed? && !resolved? && !closed?
      self.resolved_at = nil
    end
  end

  def category_must_be_valid
    return if category.blank? # Category is optional
    
    available_categories = account&.settings&.dig('ticket_categories') || []
    return if available_categories.include?(category)
    
    errors.add(:category, 'is not a valid category for this account')
  end
end
