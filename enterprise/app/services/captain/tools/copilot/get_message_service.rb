class Captain::Tools::Copilot::GetMessageService < Captain::Tools::BaseService
  def name
    'get_message'
  end

  def description
    'Get details of a specific message by its ID'
  end

  def parameters
    {
      type: 'object',
      properties: {
        message_id: {
          type: 'number',
          description: 'The ID of the message to retrieve'
        }
      },
      required: %w[message_id]
    }
  end

  def execute(arguments)
    message_id = arguments['message_id']

    Rails.logger.info "#{self.class.name}: Message ID: #{message_id}"

    return 'Missing required parameters' if message_id.blank?

    # Find the message by ID within this account's conversations
    message = Message.joins(:conversation)
                    .where(id: message_id, conversations: { account_id: @assistant.account_id })
                    .includes(:sender, :conversation, :attachments)
                    .first

    return 'Message not found' if message.blank?

    # Return formatted message details
    {
      id: message.id,
      content: message.content,
      message_type: message.message_type,
      created_at: message.created_at,
      sender: {
        id: message.sender&.id,
        name: message.sender&.name,
        email: message.sender&.email,
        type: message.sender&.class&.name
      },
      conversation: {
        id: message.conversation.id,
        display_id: message.conversation.display_id,
        subject: message.conversation.additional_attributes['subject']
      },
      private: message.private,
      source_id: message.source_id,
      attachments: message.attachments.map do |attachment|
        {
          id: attachment.id,
          file_type: attachment.file_type,
          file_url: attachment.download_url
        }
      end
    }.to_json
  end

  def active?
    user_has_permission('conversation_manage') ||
      user_has_permission('conversation_unassigned_manage') ||
      user_has_permission('conversation_participating_manage')
  end
end
