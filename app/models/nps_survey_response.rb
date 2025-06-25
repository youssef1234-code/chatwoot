# == Schema Information
#
# Table name: nps_survey_responses
#
#  id                :bigint           not null, primary key
#  feedback_message  :text
#  rating            :integer          not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  account_id        :bigint           not null
#  assigned_agent_id :bigint
#  contact_id        :bigint           not null
#  conversation_id   :bigint           not null
#  message_id        :bigint           not null
#
# Indexes
#
#  index_nps_survey_responses_on_account_id                 (account_id)
#  index_nps_survey_responses_on_account_id_and_created_at  (account_id,created_at)
#  index_nps_survey_responses_on_assigned_agent_id          (assigned_agent_id)
#  index_nps_survey_responses_on_contact_id                 (contact_id)
#  index_nps_survey_responses_on_contact_id_and_created_at  (contact_id,created_at)
#  index_nps_survey_responses_on_conversation_id            (conversation_id)
#  index_nps_survey_responses_on_message_id                 (message_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (assigned_agent_id => users.id)
#  fk_rails_...  (contact_id => contacts.id)
#  fk_rails_...  (conversation_id => conversations.id)
#  fk_rails_...  (message_id => messages.id)
#
class NpsSurveyResponse < ApplicationRecord
  belongs_to :account
  belongs_to :conversation
  belongs_to :contact
  belongs_to :message
  belongs_to :assigned_agent, class_name: 'User', optional: true, inverse_of: :nps_survey_responses

  validates :rating, presence: true, inclusion: { in: (0..10).to_a }
  validates :account_id, presence: true
  validates :contact_id, presence: true
  validates :conversation_id, presence: true

  # Filter scopes for reporting
  scope :filter_by_created_at, ->(range) { where(created_at: range) if range.present? }
  scope :filter_by_assigned_agent_id, ->(user_ids) { where(assigned_agent_id: user_ids) if user_ids.present? }
  scope :filter_by_inbox_id, ->(inbox_id) { joins(:conversation).where(conversations: { inbox_id: inbox_id }) if inbox_id.present? }
  scope :filter_by_team_id, ->(team_id) { joins(:conversation).where(conversations: { team_id: team_id }) if team_id.present? }
  scope :filter_by_rating, ->(rating) { where(rating: rating) if rating.present? }

  # Get responses for the last month for a contact
  scope :for_contact_last_month, ->(contact_id) { 
    where(contact_id: contact_id, created_at: 1.month.ago..Time.current) 
  }

  def promoter?
    rating >= 9
  end

  def passive?
    rating.in?([7, 8])
  end

  def detractor?
    rating <= 6
  end

  def nps_category
    return 'promoter' if promoter?
    return 'passive' if passive?
    
    'detractor'
  end
end
