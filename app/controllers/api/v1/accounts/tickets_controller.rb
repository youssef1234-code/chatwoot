class Api::V1::Accounts::TicketsController < Api::V1::Accounts::BaseController
  before_action :fetch_ticket, except: [:index, :create]
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

  def create
    @ticket = current_account.tickets.build(ticket_params)
    @ticket.created_by = Current.user
    @ticket.contact = @conversation.contact

    if @ticket.save
      # Link selected messages to the ticket
      link_messages_to_ticket if params[:message_ids].present?
      
      # Create activity message in conversation
      create_ticket_activity_message(:created)
      
      render :show, status: :created
    else
      render json: { errors: @ticket.errors }, status: :unprocessable_entity
    end
  end

  def update
    if @ticket.update(ticket_params)
      # Create activity message for status/priority changes
      create_ticket_activity_message(:updated) if ticket_status_or_priority_changed?
      
      render :show
    else
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
    begin
      @ticket.resolve!
      
      # Create activity message
      create_ticket_activity_message(:resolved)
      
      render :show
    rescue StandardError => e
      render json: { error: e.message }, status: :unprocessable_entity
    end
  end

  def close
    begin
      @ticket.close!
      
      # Create activity message
      create_ticket_activity_message(:closed)
      
      render :show
    rescue StandardError => e
      render json: { error: e.message }, status: :unprocessable_entity
    end
  end

  def add_messages
    message_ids = params[:message_ids] || []
    
    if message_ids.any?
      message_ids.each do |message_id|
        message = @ticket.conversation.messages.find(message_id)
        TicketMessage.link_message_to_ticket(@ticket, message)
      rescue ActiveRecord::RecordNotFound
        # Skip invalid message IDs
        next
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
    @conversation = current_account.conversations.find(ticket_params[:conversation_id])
  end

  def ticket_params
    params.require(:ticket).permit(
      :title, :description, :status, :priority, :issue_type,
      :conversation_id, :assigned_agent_id, :jira_issue_key
    )
  end

  def link_messages_to_ticket
    message_ids = params[:message_ids] || []
    
    message_ids.each do |message_id|
      message = @ticket.conversation.messages.find(message_id)
      TicketMessage.link_message_to_ticket(@ticket, message)
    rescue ActiveRecord::RecordNotFound, ActiveRecord::RecordInvalid
      # Skip invalid or already linked messages
      next
    end
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
