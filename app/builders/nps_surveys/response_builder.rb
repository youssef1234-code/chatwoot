class NpsSurveys::ResponseBuilder
  pattr_initialize [:message]

  def perform
    raise 'Invalid Message' unless message.input_nps?

    conversation = message.conversation
    rating = message.content_attributes.dig('submitted_values', 'nps_survey_response', 'rating')
    feedback_message = message.content_attributes.dig('submitted_values', 'nps_survey_response', 'feedback_message')

    return if rating.blank?

    process_nps_response(conversation, rating, feedback_message)
  end

  private

  def process_nps_response(conversation, rating, feedback_message)
    nps_survey_response = message.nps_survey_response || NpsSurveyResponse.new(
      message_id: message.id, account_id: message.account_id, conversation_id: message.conversation_id,
      contact_id: conversation.contact_id, assigned_agent: conversation.assignee
    )
    nps_survey_response.rating = rating
    nps_survey_response.feedback_message = feedback_message
    nps_survey_response.save!
    nps_survey_response
  end
end
