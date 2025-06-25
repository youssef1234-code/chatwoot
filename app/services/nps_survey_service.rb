class NpsSurveyService
  pattr_initialize [:conversation!]

  def perform
    return unless should_send_nps_survey?

    if within_messaging_window?
      ::MessageTemplates::Template::NpsSurvey.new(conversation: conversation).perform
    else
      create_nps_not_sent_activity_message
    end
  end

  private

  delegate :inbox, :contact, to: :conversation

  def should_send_nps_survey?
    conversation_allows_nps? && nps_enabled? && !nps_sent_recently?
  end

  def conversation_allows_nps?
    conversation.resolved? && !conversation.tweet?
  end

  def nps_enabled?
    # For now, we'll enable NPS for all inboxes that have CSAT enabled
    # This can be made configurable in the future
    inbox.csat_survey_enabled?
  end

  def nps_sent_recently?
    # Check if NPS was sent to this contact in the last month within this account
    conversation.account.nps_survey_responses
                       .where(contact_id: contact.id, created_at: 1.month.ago..Time.current)
                       .exists?
  end

  def within_messaging_window?
    conversation.can_reply?
  end

  def create_nps_not_sent_activity_message
    content = I18n.t('conversations.activity.nps.not_sent_due_to_messaging_window')
    activity_message_params = {
      account_id: conversation.account_id,
      inbox_id: conversation.inbox_id,
      message_type: :activity,
      content: content
    }
    ::Conversations::ActivityMessageJob.perform_later(conversation, activity_message_params) if content
  end
end
