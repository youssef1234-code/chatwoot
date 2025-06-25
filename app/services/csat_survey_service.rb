class CsatSurveyService
  pattr_initialize [:conversation!]

  def perform
    return unless should_send_csat_survey?

    if within_messaging_window?
      ::MessageTemplates::Template::CsatSurvey.new(conversation: conversation).perform
    else
      create_csat_not_sent_activity_message
    end
  end

  private

  delegate :inbox, :contact, to: :conversation

  def should_send_csat_survey?
    conversation_allows_csat? && csat_enabled? && !csat_already_sent_recently?
  end

  def conversation_allows_csat?
    conversation.resolved? && !conversation.tweet?
  end

  def csat_enabled?
    inbox.csat_survey_enabled?
  end

  def csat_already_sent_recently?
    # Check if CSAT was sent for this specific resolution cycle
    # We consider it recent if it was sent in the last hour and conversation is still resolved
    recent_csat_messages = conversation.messages.where(
      content_type: :input_csat,
      created_at: 1.hour.ago..Time.current
    )
    
    # Only prevent sending if there's a recent CSAT message and conversation hasn't been reopened since
    return false unless recent_csat_messages.exists?
    
    # Check if conversation was reopened after the last CSAT message
    last_csat_message = recent_csat_messages.order(:created_at).last
    last_activity_after_csat = conversation.messages.where(
      'created_at > ? AND message_type != ?', 
      last_csat_message.created_at, 
      Message.message_types[:activity]
    ).exists?
    
    # If there was activity after CSAT, it means conversation was reopened, so we can send CSAT again
    !last_activity_after_csat
  end

  def within_messaging_window?
    conversation.can_reply?
  end

  def create_csat_not_sent_activity_message
    content = I18n.t('conversations.activity.csat.not_sent_due_to_messaging_window')
    activity_message_params = {
      account_id: conversation.account_id,
      inbox_id: conversation.inbox_id,
      message_type: :activity,
      content: content
    }
    ::Conversations::ActivityMessageJob.perform_later(conversation, activity_message_params) if content
  end
end
