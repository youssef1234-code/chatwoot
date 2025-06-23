class Api::V1::Accounts::TicketsController < Api::V1::Accounts::BaseController
  before_action :fetch_ticket, except: %i[index create]
  before_action :fetch_conversation, only: [:create]

  def index
    @tickets = current_account.tickets
                              .includes(:conversation, :contact, :created_by, :assigned_agent, :ticket_messages)

    @tickets = @tickets.for_conversation(params[:conversation_id]) if params[:conversation_id].present?
    @tickets = @tickets.by_status(params[:status]) if params[:status].present?
    @tickets = @tickets.by_priority(params[:priority]) if params[:priority].present?
    @tickets = @tickets.created_by(params[:created_by_id]) if params[:created_by_id].present?
    @tickets = @tickets.assigned_to(params[:assigned_agent_id]) if params[:assigned_agent_id].present?

    @tickets = @tickets.page(params[:page]).per(params[:per_page] || 25)
  end

  def show
    # Ticket is already fetched in before_action
  end

  def messages
    Rails.logger.info '=== TICKET MESSAGES DEBUG ==='
    Rails.logger.info "Ticket ID: #{@ticket.id}"
    Rails.logger.info "Ticket Messages count: #{@ticket.ticket_messages.count}"

    @ticket.ticket_messages.each do |tm|
      Rails.logger.info "TicketMessage ID: #{tm.id}, Message ID: #{tm.message_id}"
    end

    @messages = @ticket.ticket_messages
                       .includes(message: %i[sender conversation attachments])
                       .joins(:message)
                       .order('messages.created_at ASC')
                       .map(&:message)

    Rails.logger.info "Final messages count: #{@messages.count}"

    render json: {
      messages: @messages.map do |message|
        {
          id: message.id,
          content: message.content,
          message_type: message.message_type,
          content_type: message.content_type,
          private: message.private,
          sender: if message.sender
                    {
                      id: message.sender.id,
                      name: message.sender.name,
                      email: message.sender.email,
                      avatar_url: message.sender.avatar_url
                    }
                  else
                    nil
                  end,
          created_at: message.created_at,
          updated_at: message.updated_at,
          attachments: message.attachments.map do |attachment|
            {
              id: attachment.id,
              file_type: attachment.file_type,
              file_url: attachment.file_url,
              thumb_url: attachment.thumb_url
            }
          end
        }
      end
    }
  end

  def create
    Rails.logger.info '=== TICKET CREATE DEBUG ==='
    Rails.logger.info "Received params: #{params.inspect}"
    Rails.logger.info "message_ids param: #{params[:message_ids].inspect}"

    @ticket = current_account.tickets.build(ticket_params)
    @ticket.created_by = Current.user
    @ticket.contact = @conversation.contact

    if @ticket.save
      Rails.logger.info "Ticket saved successfully with ID: #{@ticket.id}"

      # Link selected messages to the ticket
      if params[:message_ids].present?
        Rails.logger.info 'Linking messages to ticket...'
        link_messages_to_ticket
        Rails.logger.info "Messages linked. Ticket now has #{@ticket.ticket_messages.count} linked messages"
      else
        Rails.logger.info 'No message_ids provided'
      end

      # Create activity message in conversation
      create_ticket_activity_message(:created)

      render :show, status: :created
    else
      render json: { errors: @ticket.errors }, status: :unprocessable_entity
    end
  end

  def update
    Rails.logger.info '=== TICKET UPDATE DEBUG ==='
    Rails.logger.info "Received params: #{params.inspect}"
    Rails.logger.info "ticket_params: #{ticket_params.inspect}"
    Rails.logger.info "Current assigned_agent_id: #{@ticket.assigned_agent_id}"

    if @ticket.update(ticket_params)
      Rails.logger.info "Updated assigned_agent_id: #{@ticket.assigned_agent_id}"
      # Create activity message for status/priority changes
      create_ticket_activity_message(:updated) if ticket_status_or_priority_changed?

      render :show
    else
      Rails.logger.error "Ticket update errors: #{@ticket.errors.full_messages}"
      render json: { errors: @ticket.errors }, status: :unprocessable_entity
    end
  end

  def destroy
    @ticket.destroy!

    # Create activity message in conversation
    create_ticket_activity_message(:deleted)

    head :no_content
  end

  def escalate_to_jira
    jira_issue_key = params[:jira_issue_key]

    if jira_issue_key.blank?
      render json: { error: 'JIRA issue key is required' }, status: :unprocessable_entity
      return
    end

    begin
      @ticket.escalate_to_jira!(jira_issue_key)

      # Create activity message
      create_ticket_activity_message(:escalated_to_jira)

      render :show
    rescue StandardError => e
      render json: { error: e.message }, status: :unprocessable_entity
    end
  end

  def resolve
    @ticket.resolve!

    # Create activity message
    create_ticket_activity_message(:resolved)

    render :show
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def close
    @ticket.close!

    # Create activity message
    create_ticket_activity_message(:closed)

    render :show
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def add_messages
    message_ids = params[:message_ids] || []
    if message_ids.any?
      message_ids.each do |message_id|
        message = @ticket.messages.find(message_id)
        TicketMessage.link_message_to_ticket(@ticket, message)
      rescue ActiveRecord::RecordInvalid
        # Skip already linked messages
        next
      end

      render :show
    else
      render json: { error: 'No message IDs provided' }, status: :unprocessable_entity
    end
  end

  def remove_messages
    message_ids = params[:message_ids] || []

    if message_ids.any?
      @ticket.ticket_messages.where(message_id: message_ids).destroy_all
      render :show
    else
      render json: { error: 'No message IDs provided' }, status: :unprocessable_entity
    end
  end

  private

  def fetch_ticket
    @ticket = current_account.tickets.find(params[:id])
  end

  def fetch_conversation
    conversation_id = params.dig(:ticket, :conversation_id)

    return render json: { error: 'Conversation ID is required' }, status: :bad_request if conversation_id.blank?

    # Fetch all conversations for the current account
    conversations = current_account.conversations

    # Apply permission filtering
    filtered_conversations = Conversations::PermissionFilterService.new(
      conversations,
      Current.user,
      current_account
    ).perform

    @conversation = filtered_conversations.find(conversation_id)
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Conversation not found or you don't have access to it" }, status: :not_found
  end

  def ticket_params
    params.require(:ticket).permit(
      :title, :description, :status, :priority, :issue_type,
      :conversation_id, :assigned_agent_id, :jira_issue_key
    )
  end

  def link_messages_to_ticket
    message_ids = params[:message_ids] || []
    Rails.logger.info '=== LINKING MESSAGES TO TICKET ==='
    Rails.logger.info "message_ids to link: #{message_ids.inspect}"
    Rails.logger.info "Ticket ID: #{@ticket.id}"
    Rails.logger.info "Conversation ID: #{@ticket.conversation.id}"

    message_ids.each do |message_id|
      Rails.logger.info "Processing message ID: #{message_id}"
      
      # Find message universally, then verify it belongs to the same account
      message = Message.find(message_id)
      
      # Security check: ensure message belongs to the same account
      unless message.account_id == current_account.id
        Rails.logger.error "Security violation: Message #{message_id} belongs to different account"
        next
      end
      
      Rails.logger.info "Found message: #{message.id} - #{message.content&.truncate(50)}"
      Rails.logger.info "Message conversation: #{message.conversation_id}, Ticket conversation: #{@ticket.conversation.id}"

      ticket_message = TicketMessage.link_message_to_ticket(@ticket, message)
      Rails.logger.info "Created TicketMessage: #{ticket_message.id}"
    rescue ActiveRecord::RecordNotFound => e
      Rails.logger.error "Message not found: #{message_id} - #{e.message}"
      next
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error "Failed to link message #{message_id}: #{e.message}"
      next
    end

    Rails.logger.info "Finished linking. Total linked messages: #{@ticket.ticket_messages.count}"
  end

  def ticket_status_or_priority_changed?
    @ticket.previous_changes.key?('status') || @ticket.previous_changes.key?('priority')
  end

  def create_ticket_activity_message(action_type)
    message_content = case action_type
                      when :created
                        "Ticket ##{@ticket.id} \"#{@ticket.title}\" was created"
                      when :updated
                        "Ticket ##{@ticket.id} \"#{@ticket.title}\" was updated"
                      when :deleted
                        "Ticket ##{@ticket.id} \"#{@ticket.title}\" was deleted"
                      when :escalated_to_jira
                        "Ticket ##{@ticket.id} \"#{@ticket.title}\" was escalated to JIRA (#{@ticket.jira_issue_key})"
                      when :resolved
                        "Ticket ##{@ticket.id} \"#{@ticket.title}\" was resolved"
                      when :closed
                        "Ticket ##{@ticket.id} \"#{@ticket.title}\" was closed"
                      end

    Messages::MessageBuilder.new(
      Current.user,
      @ticket.conversation,
      {
        content: message_content,
        message_type: 'activity',
        private: false,
        content_attributes: {
          ticket_id: @ticket.id,
          action_type: action_type.to_s
        }
      }
    ).perform
  end
end
