class Public::Api::V1::NpsSurveyController < PublicController
  before_action :set_conversation
  before_action :set_message

  def show; end

  def update
    render json: { error: 'You cannot update the NPS survey after 14 days' }, status: :unprocessable_entity and return if check_nps_locked

    @message.update!(message_update_params[:message])
  end

  private

  def set_conversation
    return if params[:id].blank?

    @conversation = Conversation.find_by!(uuid: params[:id])
  end

  def set_message
    @message = @conversation.messages.find_by!(content_type: 'input_nps')
  end

  def message_update_params
    params.permit(message: [{ submitted_values: [:name, :title, :value, { nps_survey_response: [:feedback_message, :rating] }] }])
  end

  def check_nps_locked
    (Time.zone.now.to_date - @message.created_at.to_date).to_i > 14
  end
end
