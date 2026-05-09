# == Schema Information
#
# Table name: jira_onboarding_statuses
#
#  id                   :bigint           not null, primary key
#  contact_email        :string
#  current_session      :string
#  last_fetched_at      :datetime
#  onboarding_key       :string
#  onboarding_status    :string
#  onboarding_summary   :string
#  onboarding_url       :string
#  organization_name    :string           not null
#  overall_percent      :integer          default(0)
#  raw_response         :jsonb
#  sessions_data        :jsonb
#  sessions_done        :integer          default(0)
#  sessions_in_progress :integer          default(0)
#  sessions_total       :integer          default(0)
#  stage                :string
#  tasks_done           :integer          default(0)
#  tasks_total          :integer          default(0)
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  account_id           :bigint           not null
#
# Indexes
#
#  idx_jira_onboarding_on_account_org                   (account_id,organization_name) UNIQUE
#  index_jira_onboarding_statuses_on_account_id         (account_id)
#  index_jira_onboarding_statuses_on_last_fetched_at    (last_fetched_at)
#  index_jira_onboarding_statuses_on_onboarding_key     (onboarding_key)
#  index_jira_onboarding_statuses_on_organization_name  (organization_name)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
class JiraOnboardingStatus < ApplicationRecord
  belongs_to :account

  validates :organization_name, presence: true
  validates :organization_name, uniqueness: { scope: :account_id }

  scope :for_account, ->(account_id) { where(account_id: account_id) }
  scope :for_org, ->(org_name) { where(organization_name: org_name) }
  scope :stale, -> { where('last_fetched_at IS NULL OR last_fetched_at < ?', 5.minutes.ago) }

  # Update from JIRA ScriptRunner API response
  def update_from_jira(data)
    # Treat nil response OR response with null onboarding as "not in onboarding"
    return mark_not_in_onboarding! if data.nil? || data['onboarding'].nil?

    onboarding = data['onboarding'] || {}
    progress = data['progress'] || {}

    update!(
      onboarding_key: onboarding['key'],
      onboarding_status: onboarding['status'],
      onboarding_summary: onboarding['summary'],
      current_session: onboarding['current_session'],
      contact_email: onboarding['contact_email'],
      onboarding_url: onboarding['url'],
      stage: progress['stage'],
      sessions_total: progress['sessions_total'] || 0,
      sessions_done: progress['sessions_done'] || 0,
      sessions_in_progress: progress['sessions_in_progress'] || 0,
      tasks_total: progress['tasks_total'] || 0,
      tasks_done: progress['tasks_done'] || 0,
      overall_percent: progress['overall_percent'] || 0,
      sessions_data: data['sessions'] || [],
      raw_response: data,
      last_fetched_at: Time.current
    )
  end

  def mark_not_in_onboarding!
    update!(
      onboarding_key: nil,
      onboarding_status: nil,
      onboarding_summary: nil,
      current_session: nil,
      contact_email: nil,
      onboarding_url: nil,
      stage: 'not_in_onboarding',
      sessions_total: 0,
      sessions_done: 0,
      sessions_in_progress: 0,
      tasks_total: 0,
      tasks_done: 0,
      overall_percent: 0,
      sessions_data: [],
      raw_response: {},
      last_fetched_at: Time.current
    )
  end

  def stale?
    last_fetched_at.nil? || last_fetched_at < 5.minutes.ago
  end

  def not_in_onboarding?
    stage == 'not_in_onboarding' && onboarding_key.nil?
  end

  # Build the response hash matching the JIRA ScriptRunner format
  def to_api_response
    return nil if not_in_onboarding?
    # Prefer the raw JIRA response — it's the most complete
    return raw_response if raw_response.present? && raw_response['onboarding'].present?

    {
      org: organization_name,
      onboarding: {
        key: onboarding_key,
        status: onboarding_status,
        summary: onboarding_summary,
        current_session: current_session,
        contact_email: contact_email,
        url: onboarding_url
      },
      progress: {
        stage: stage,
        sessions_total: sessions_total,
        sessions_done: sessions_done,
        sessions_in_progress: sessions_in_progress,
        tasks_total: tasks_total,
        tasks_done: tasks_done,
        overall_percent: overall_percent
      },
      sessions: sessions_data
    }
  end
end
