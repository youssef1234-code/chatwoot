class CsatSurveyListener < BaseListener
  def conversation_status_changed(event)
    conversation = extract_conversation_and_account(event)[0]

    return unless conversation.resolved?

    # Send CSAT survey when conversation is resolved
    CsatSurveyService.new(conversation: conversation).perform
    
    # Also consider sending NPS survey (with monthly limit)
    NpsSurveyService.new(conversation: conversation).perform
  end

  def message_updated(event)
    message = extract_message_and_account(event)[0]
    
    if message.input_csat?
      CsatSurveys::ResponseBuilder.new(message: message).perform
    elsif message.input_nps?
      NpsSurveys::ResponseBuilder.new(message: message).perform
    end
  end
end
