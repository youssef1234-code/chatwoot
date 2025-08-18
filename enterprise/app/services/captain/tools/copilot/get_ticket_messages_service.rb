class Captain::Tools::Copilot::GetTicketMessagesService < Captain::Tools::BaseService
  def name
    'get_ticket_messages'
  end

  def description
    'Get all messages linked to a specific ticket including conversation messages and ticket messages'
  end

  def parameters
    {
      type: 'object',
      properties: {
        ticket_id: {
          type: 'number',
          description: 'The ID of the ticket to retrieve messages for'
        }
      },
      required: %w[ticket_id]
    }
  end

  def execute(arguments)
    ticket_id = arguments['ticket_id']

    Rails.logger.info "#{self.class.name}: Ticket ID: #{ticket_id}"

    return 'Missing required parameters' if ticket_id.blank?

    # Find the ticket within this account
    ticket = Ticket.find_by(id: ticket_id, account_id: @assistant.account_id)
    return 'Ticket not found' if ticket.blank?

    result = {
      ticket: {
        id: ticket.id,
        title: ticket.title,
        description: ticket.description,
        status: ticket.status,
        priority: ticket.priority,
        conversation_id: ticket.conversation_id
      },
      conversation_messages: [],
      ticket_messages: []
    }

    # Get conversation messages if ticket has a linked conversation
    if ticket.conversation.present?
      conversation_messages = ticket.conversation.messages
                                   .where(private: false)
                                   .order(:created_at)
                                   .includes(:sender, :attachments)

      result[:conversation_messages] = conversation_messages.map do |message|
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
          private: message.private,
          attachments: message.attachments.map do |attachment|
            {
              id: attachment.id,
              file_type: attachment.file_type,
              file_url: attachment.download_url
            }
          end
        }
      end
    end

    # Get ticket messages (direct links to messages)
    if ticket.ticket_messages.any?
      ticket_messages = ticket.ticket_messages.includes(:message => [:sender, :attachments])

      result[:ticket_messages] = ticket_messages.map do |ticket_message|
        message = ticket_message.message
        next unless message

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
          private: message.private,
          attachments: message.attachments.map do |attachment|
            {
              id: attachment.id,
              file_type: attachment.file_type,
              file_url: attachment.download_url
            }
          end
        }
      end.compact
    end

    result.to_json
  end

  def active?
    user_has_permission('conversation_manage') ||
      user_has_permission('conversation_unassigned_manage') ||
      user_has_permission('conversation_participating_manage')
  end
end
