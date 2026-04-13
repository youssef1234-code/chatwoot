class Api::V1::Accounts::TicketsController < Api::V1::Accounts::BaseController
  before_action :fetch_ticket, except: %i[index create analytics kanban]
  before_action :fetch_conversation, only: [:create]
  before_action :ensure_administrator, only: [:destroy]

  # GET /api/v1/accounts/:account_id/tickets/analytics
  # Returns counts per status for Kanban header (optimized - no ticket data)
  def analytics
    base_scope = current_account.tickets

    # Apply same filters as index
    if params[:is_feature_request].present?
      case params[:is_feature_request]
      when 'true'
        base_scope = base_scope.feature_requests
      when 'false'
        base_scope = base_scope.regular_tickets
      end
    else
      base_scope = base_scope.regular_tickets unless params[:include_feature_requests] == 'true'
    end

    # Group by status and count
    status_counts = base_scope.group(:status).count

    # Calculate derived counts for Kanban columns
    analytics = {
      total: status_counts.values.sum,
      not_done: status_counts['open'] || 0,
      in_progress: (status_counts['in_progress'] || 0),
      escalated: (status_counts['escalated'] || 0),
      done: (status_counts['resolved'] || 0) + (status_counts['closed'] || 0),
      # Include the raw status counts too
      by_status: {
        open: status_counts['open'] || 0,
        in_progress: status_counts['in_progress'] || 0,
        escalated: status_counts['escalated'] || 0,
        resolved: status_counts['resolved'] || 0,
        closed: status_counts['closed'] || 0
      },
      # Plane state breakdown for dynamic columns
      by_plane_state: base_scope.where.not(plane_state: [nil, '']).group(:plane_state).count,
      # Priority breakdown
      by_priority: base_scope.group(:priority).count,
      # JIRA escalated count
      jira_escalated: base_scope.where.not(jira_issue_key: nil).count,
      # Plane escalated count
      plane_escalated: base_scope.where.not(plane_issue_id: nil).count
    }

    render json: analytics, status: :ok
  end

  # GET /api/v1/accounts/:account_id/tickets/kanban
  # Returns paginated tickets for a specific Kanban column with cursor-based pagination
  def kanban
    column = params[:column] || 'all'
    cursor = params[:cursor] # Last ticket ID for infinite scroll
    limit = (params[:limit] || 20).to_i.clamp(1, 100)

    base_scope = current_account.tickets
                              .includes(:conversation, :contact, :created_by, :assigned_agent)
                              .order(id: :desc)

    # Apply feature request filter
    if params[:is_feature_request].present?
      case params[:is_feature_request]
      when 'true'
        base_scope = base_scope.feature_requests
      when 'false'
        base_scope = base_scope.regular_tickets
      end
    else
      base_scope = base_scope.regular_tickets unless params[:include_feature_requests] == 'true'
    end

    # Filter by column (status)
    status_val = params[:status]
    plane_state_filter = params[:plane_state]

    @tickets = if plane_state_filter.present?
                 # Filter by plane_state for dynamic Plane columns
                 base_scope.where(plane_state: plane_state_filter)
               elsif status_val.present?
                 # Direct status filter (supports comma-separated)
                 statuses = status_val.split(',').map(&:strip)
                 base_scope.where(status: statuses)
               else
                 base_scope
               end

    # Apply cursor-based pagination (for infinite scroll)
    @tickets = @tickets.where('tickets.id < ?', cursor) if cursor.present?

    # Get one extra to check if there are more
    tickets_with_extra = @tickets.limit(limit + 1).to_a
    has_more = tickets_with_extra.size > limit
    @tickets = tickets_with_extra.take(limit)

    # Get next cursor
    next_cursor = @tickets.last&.id

    render json: {
      tickets: @tickets.map { |ticket| serialize_ticket_for_kanban(ticket) },
      pagination: {
        has_more: has_more,
        next_cursor: has_more ? next_cursor : nil,
        count: @tickets.size
      }
    }, status: :ok
  end

  def index
    @tickets = current_account.tickets
                              .includes(:conversation, :contact, :created_by, :assigned_agent, :ticket_messages)
                              .order(id: :desc) # Sort by ID in descending order (newest first)

    # Feature request filtering
    if params[:is_feature_request].present?
      case params[:is_feature_request]
      when 'true'
        @tickets = @tickets.feature_requests
      when 'false'
        @tickets = @tickets.regular_tickets
      end
    else
      # By default, exclude feature requests unless explicitly requested
      @tickets = @tickets.regular_tickets unless params[:include_feature_requests] == 'true'
    end

    # Enhanced conversation filtering for sidebar
    if params[:conversation_id].present?
      conversation_id = params[:conversation_id]

      # Find tickets that either:
      # 1. Have the conversation_id directly (primary conversation), OR
      # 2. Have messages linked from this conversation
      tickets_with_messages_from_conversation = current_account.tickets
                                                               .joins(:ticket_messages)
                                                               .joins('INNER JOIN messages ON ticket_messages.message_id = messages.id')
                                                               .where('messages.conversation_id = ?', conversation_id)
                                                               .distinct
                                                               .pluck(:id)

      @tickets = @tickets.where(
        'tickets.conversation_id = ? OR tickets.id IN (?)',
        conversation_id,
        tickets_with_messages_from_conversation.presence || [0] # Use [0] to avoid empty IN clause
      )
    end

    @tickets = @tickets.by_status(params[:status]) if params[:status].present?
    @tickets = @tickets.by_priority(params[:priority]) if params[:priority].present?
    @tickets = @tickets.created_by(params[:created_by_id]) if params[:created_by_id].present?
    @tickets = @tickets.assigned_to(params[:assigned_agent_id]) if params[:assigned_agent_id].present?

    # Get total count before pagination
    @total_count = @tickets.count

    @tickets = @tickets.page(params[:page]).per(params[:per_page] || 25)

    # Set pagination headers
    response.headers['X-Total-Count'] = @total_count.to_s
    response.headers['X-Current-Page'] = @tickets.current_page.to_s
    response.headers['X-Per-Page'] = @tickets.limit_value.to_s
    response.headers['X-Total-Pages'] = @tickets.total_pages.to_s
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
                      email: message.sender.respond_to?(:email) ? message.sender.email : nil,
                      avatar_url: message.sender.respond_to?(:avatar_url) ? message.sender.avatar_url : nil,
                      type: message.sender.class.name
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
    Rails.logger.info '=== TICKET CONTACT DEBUG ==='
    Rails.logger.info "Message IDs: #{params[:message_ids].inspect}"
    Rails.logger.info "Conversation from params: #{@conversation.id} (contact: #{@conversation.contact&.name})"

    @ticket = current_account.tickets.build(ticket_params)
    @ticket.created_by = Current.user

    # Set contact based on message context if messages are provided
    if params[:message_ids].present? && params[:message_ids].any?
      # Get the contact from the first message's conversation
      first_message_id = params[:message_ids].first
      begin
        first_message = Message.find(first_message_id)
        if first_message.account_id == current_account.id
          message_conversation = first_message.conversation
          @ticket.contact = message_conversation.contact
          Rails.logger.info "Using contact from message conversation: #{message_conversation.id} (contact: #{message_conversation.contact&.name})"
        else
          # Fallback to conversation from params if security check fails
          @ticket.contact = @conversation.contact
          Rails.logger.info 'Security fallback: using contact from params conversation'
        end
      rescue ActiveRecord::RecordNotFound
        # Fallback to conversation from params if message not found
        @ticket.contact = @conversation.contact
        Rails.logger.info 'Message not found fallback: using contact from params conversation'
      end
    else
      # Use contact from the conversation in params if no messages
      @ticket.contact = @conversation.contact
      Rails.logger.info 'No messages: using contact from params conversation'
    end

    Rails.logger.info "Final ticket contact: #{@ticket.contact&.name}"

    if @ticket.save
      # Link selected messages to the ticket
      link_messages_to_ticket if params[:message_ids].present?

      # Create activity message in conversation
      create_ticket_activity_message(:created)

      # Broadcast ticket creation to WebSocket
      broadcast_ticket_created

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

      # Broadcast ticket update to WebSocket
      broadcast_ticket_updated

      render :show
    else
      Rails.logger.error "Ticket update errors: #{@ticket.errors.full_messages}"
      render json: { errors: @ticket.errors }, status: :unprocessable_entity
    end
  end

  def destroy
    # Store ticket data before deletion for broadcasting
    ticket_data = {
      id: @ticket.id,
      conversation_id: @ticket.conversation_id,
      account_id: current_account.id
    }

    # Delete the ticket and its message links, but preserve JIRA issue
    # Ticket messages will be automatically deleted due to dependent: :destroy
    @ticket.destroy!

    # Create activity message in conversation to notify about ticket deletion
    create_ticket_activity_message(:deleted)

    # Broadcast ticket deletion to all connected clients
    broadcast_ticket_deleted(ticket_data)

    head :no_content
  rescue StandardError => e
    Rails.logger.error "Error deleting ticket #{@ticket.id}: #{e.message}"
    render json: { error: 'Failed to delete ticket' }, status: :internal_server_error
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

      # Broadcast ticket update to WebSocket for real-time updates
      broadcast_ticket_updated

      render :show
    rescue StandardError => e
      render json: { error: e.message }, status: :unprocessable_entity
    end
  end

  def escalate_to_plane
    plane_issue_id = params[:plane_issue_id]
    plane_issue_key = params[:plane_issue_key]
    plane_project_id = params[:plane_project_id]

    if plane_issue_id.blank? || plane_project_id.blank?
      render json: { error: 'Plane issue ID and project ID are required' }, status: :unprocessable_entity
      return
    end

    begin
      @ticket.escalate_to_plane!(plane_issue_id, plane_issue_key, plane_project_id)

      # Create activity message
      create_ticket_activity_message(:escalated_to_plane)

      # Broadcast ticket update to WebSocket for real-time updates
      broadcast_ticket_updated

      render :show
    rescue StandardError => e
      render json: { error: e.message }, status: :unprocessable_entity
    end
  end

  def link_jira_issue
    jira_issue_key = params[:jira_issue_key]
    jira_url = params[:jira_url]

    if jira_issue_key.blank?
      render json: { error: 'JIRA issue key is required' }, status: :unprocessable_entity
      return
    end

    begin
      @ticket.update!(
        jira_issue_key: jira_issue_key,
        jira_url: jira_url,
        escalated_to_jira: true
      )

      create_ticket_activity_message(:linked_to_jira)
      broadcast_ticket_updated

      render :show
    rescue StandardError => e
      render json: { error: e.message }, status: :unprocessable_entity
    end
  end

  def link_plane_issue
    plane_issue_id = params[:plane_issue_id]
    plane_issue_key = params[:plane_issue_key]
    plane_project_id = params[:plane_project_id]

    if plane_issue_id.blank? || plane_project_id.blank?
      render json: { error: 'Plane issue ID and project ID are required' }, status: :unprocessable_entity
      return
    end

    begin
      @ticket.update!(
        plane_issue_id: plane_issue_id,
        plane_issue_key: plane_issue_key,
        plane_project_id: plane_project_id,
        escalated_to_plane: true
      )

      create_ticket_activity_message(:linked_to_plane)
      broadcast_ticket_updated

      render :show
    rescue StandardError => e
      render json: { error: e.message }, status: :unprocessable_entity
    end
  end

  def escalate
    note = params[:note]

    begin
      @ticket.escalate!

      # Create activity message with optional note
      message_content = note.present? ? "Ticket escalated: #{note}" : 'Ticket escalated'
      create_ticket_activity_message(:escalated, message_content)

      # Broadcast ticket update to WebSocket for real-time updates
      broadcast_ticket_updated

      render :show
    rescue StandardError => e
      render json: { error: e.message }, status: :unprocessable_entity
    end
  end

  def resolve
    @ticket.resolve!

    # Create activity message
    create_ticket_activity_message(:resolved)

    # Broadcast ticket update to WebSocket for real-time updates
    broadcast_ticket_updated

    render :show
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def close
    @ticket.close!

    # Create activity message
    create_ticket_activity_message(:closed)

    # Broadcast ticket update to WebSocket for real-time updates
    broadcast_ticket_updated

    render :show
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def mark_already_working
    @ticket.mark_already_working!

    create_ticket_activity_message(:marked_already_working)
    broadcast_ticket_updated

    render :show
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def mark_bad_config
    @ticket.mark_bad_config!

    create_ticket_activity_message(:marked_bad_config)
    broadcast_ticket_updated

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

      # Broadcast ticket update to WebSocket for real-time updates
      broadcast_ticket_updated

      render :show
    else
      render json: { error: 'No message IDs provided' }, status: :unprocessable_entity
    end
  end

  def remove_messages
    message_ids = params[:message_ids] || []

    if message_ids.any?
      @ticket.ticket_messages.where(message_id: message_ids).destroy_all

      # Broadcast ticket update to WebSocket for real-time updates
      broadcast_ticket_updated

      render :show
    else
      render json: { error: 'No message IDs provided' }, status: :unprocessable_entity
    end
  end

  def enhance_with_ai
    # Get the OpenAI hook for the account
    openai_hook = current_account.hooks.find_by(app_id: 'openai', status: 'enabled')

    if openai_hook.blank?
      render json: { error: 'OpenAI integration is not configured or enabled for this account' },
             status: :unprocessable_entity
      return
    end

    enhancement_options = params[:enhancement_options] || []

    if enhancement_options.empty?
      render json: { error: 'At least one enhancement option must be selected' }, status: :unprocessable_entity
      return
    end

    begin
      # Get linked messages content for the ticket
      linked_messages_content = get_linked_messages_content(@ticket)

      # Build the enhancement data
      enhancement_data = {
        title: @ticket.title || '',
        description: @ticket.description || '',
        messages: linked_messages_content,
        enhancement_options: enhancement_options
      }

      # Call the OpenAI processor service
      result = openai_hook.process_event({
                                           event: 'enhance_ticket',
                                           data: enhancement_data
                                         })

      if result && result[:error].blank?
        # Parse the AI response
        enhanced_data = parse_ai_enhancement_response(result)

        render json: {
          success: true,
          enhanced_data: enhanced_data,
          message: 'Ticket enhanced successfully with AI'
        }
      else
        error_message = result[:error] || 'Failed to enhance ticket with AI'
        render json: { error: error_message }, status: :unprocessable_entity
      end
    rescue StandardError => e
      Rails.logger.error "AI enhancement error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      render json: { error: 'An error occurred while enhancing the ticket with AI' }, status: :internal_server_error
    end
  end

  private

  def ensure_administrator
    return if Current.account_user&.administrator? && Current.account_user&.custom_role_id.nil?

    render json: { error: 'Access denied. Administrator privileges required.' }, status: :forbidden
  end

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

    @conversation = filtered_conversations.find_by(display_id: conversation_id)
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Conversation not found or you don't have access to it" }, status: :not_found
  end

  def ticket_params
    params.require(:ticket).permit(
      :title, :description, :status, :priority, :category,
      :conversation_id, :assigned_agent_id, :jira_issue_key, :is_feature_request
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

  def create_ticket_activity_message(action_type, custom_message = nil)
    message_content = custom_message || case action_type
                                        when :created
                                          "Ticket ##{@ticket.id} \"#{@ticket.title}\" was created"
                                        when :updated
                                          "Ticket ##{@ticket.id} \"#{@ticket.title}\" was updated"
                                        when :deleted
                                          "Ticket ##{@ticket.id} \"#{@ticket.title}\" was deleted"
                                        when :escalated
                                          "Ticket ##{@ticket.id} \"#{@ticket.title}\" was escalated"
                                        when :escalated_to_jira
                                          "Ticket ##{@ticket.id} \"#{@ticket.title}\" was escalated to JIRA (#{@ticket.jira_issue_key})"
                                        when :resolved
                                          "Ticket ##{@ticket.id} \"#{@ticket.title}\" was resolved"
                                        when :closed
                                          "Ticket ##{@ticket.id} \"#{@ticket.title}\" was closed"
                                        end

    # Determine the correct conversation for the system message
    target_conversation = determine_target_conversation_for_activity_message(action_type)

    Messages::MessageBuilder.new(
      Current.user,
      target_conversation,
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

  def broadcast_ticket_created
    # Broadcast to the account channel for real-time updates
    Rails.logger.info "Broadcasting ticket creation: #{@ticket.id}"

    ActionCable.server.broadcast(
      "account_#{current_account.id}",
      {
        event: 'ticket_created',
        data: {
          id: @ticket.id,
          title: @ticket.title,
          description: @ticket.description,
          status: @ticket.status,
          priority: @ticket.priority,
          is_feature_request: @ticket.is_feature_request,
          conversation_id: @ticket.conversation_id,
          account_id: current_account.id,
          conversation: {
            id: @ticket.conversation.id,
            display_id: @ticket.conversation.display_id,
            status: @ticket.conversation.status
          },
          contact: @ticket.contact,
          assigned_agent: @ticket.assigned_agent,
          created_by: @ticket.created_by,
          created_at: @ticket.created_at,
          updated_at: @ticket.updated_at,
          jira_issue_key: @ticket.jira_issue_key,
          jira_status: @ticket.jira_status,
          jira_in_progress: @ticket.jira_in_progress?
        }
      }
    )
  end

  def broadcast_ticket_updated
    # Broadcast to the account channel for real-time updates
    Rails.logger.info "Broadcasting ticket update: #{@ticket.id}"

    ActionCable.server.broadcast(
      "account_#{current_account.id}",
      {
        event: 'ticket_updated',
        data: {
          id: @ticket.id,
          title: @ticket.title,
          description: @ticket.description,
          status: @ticket.status,
          priority: @ticket.priority,
          is_feature_request: @ticket.is_feature_request,
          conversation_id: @ticket.conversation_id,
          account_id: current_account.id,
          conversation: {
            id: @ticket.conversation.id,
            display_id: @ticket.conversation.display_id,
            status: @ticket.conversation.status
          },
          contact: @ticket.contact,
          assigned_agent: @ticket.assigned_agent,
          created_by: @ticket.created_by,
          created_at: @ticket.created_at,
          updated_at: @ticket.updated_at,
          jira_issue_key: @ticket.jira_issue_key,
          jira_status: @ticket.jira_status,
          jira_in_progress: @ticket.jira_in_progress?
        }
      }
    )
  end

  def get_linked_messages_content(ticket)
    # Get linked messages for the ticket
    linked_messages = ticket.ticket_messages
                            .includes(message: %i[sender conversation])
                            .joins(:message)
                            .order('messages.created_at ASC')
                            .map(&:message)

    return '' if linked_messages.empty?

    # Format messages for AI processing
    messages_content = linked_messages.map do |message|
      sender_type = message.incoming? ? 'Customer' : 'Agent'
      sender_name = message.sender&.name || 'Unknown'
      timestamp = message.created_at.strftime('%Y-%m-%d %H:%M:%S')

      "[#{timestamp}] #{sender_type} (#{sender_name}): #{message.content}"
    end

    messages_content.join("\n")
  end

  def parse_ai_enhancement_response(result)
    # Handle different response formats from OpenAI
    response_text = result.is_a?(String) ? result : result.to_s

    begin
      # Try to parse as JSON first
      parsed_response = JSON.parse(response_text)

      # Handle nested message structure if present
      if parsed_response.is_a?(Hash) && parsed_response['message']
        message_content = parsed_response['message']
        if message_content.is_a?(String)
          # Try to parse the message content as JSON
          begin
            parsed_response = JSON.parse(message_content)
          rescue JSON::ParserError
            # If message content is not JSON, use it as description
            parsed_response = { 'description' => message_content }
          end
        else
          parsed_response = message_content
        end
      end

      # Ensure we return a hash with expected keys
      {
        title: parsed_response['title'] || parsed_response['enhanced_title'],
        description: parsed_response['description'] || parsed_response['enhanced_description'],
        priority: parsed_response['priority'] || parsed_response['suggested_priority'],
        labels: parsed_response['labels'] || parsed_response['suggested_labels'] || [],
        recommendations: parsed_response['recommendations'] || parsed_response['action_recommendations'] || []
      }.compact
    rescue JSON::ParserError => e
      Rails.logger.warn "Failed to parse AI response as JSON: #{e.message}"
      Rails.logger.warn "Response was: #{response_text}"

      # Fallback: treat the entire response as description
      {
        description: response_text.strip
      }
    end
  end

  def determine_target_conversation_for_activity_message(action_type)
    # For all ticket actions, if there are linked messages, create the system message
    # in the conversation where the messages actually came from, not the display conversation
    if @ticket.ticket_messages.any?
      # Get the conversation from the first linked message
      first_linked_message = @ticket.ticket_messages.includes(:message).first&.message
      if first_linked_message
        Rails.logger.info "Creating activity message in actual conversation: #{first_linked_message.conversation_id} instead of display conversation: #{@ticket.conversation_id} for action: #{action_type}"
        return first_linked_message.conversation
      end
    end

    # If no linked messages, use the ticket's assigned conversation
    Rails.logger.info "No linked messages found, using ticket's assigned conversation: #{@ticket.conversation_id} for action: #{action_type}"
    @ticket.conversation
  end

  def broadcast_ticket_deleted(ticket_data)
    # Broadcast to the account channel for real-time updates
    Rails.logger.info "Broadcasting ticket deletion: #{ticket_data[:id]}"

    ActionCable.server.broadcast(
      "account_#{current_account.id}",
      {
        event: 'ticket_deleted',
        data: {
          ticket_id: ticket_data[:id],
          conversation_id: ticket_data[:conversation_id],
          account_id: ticket_data[:account_id]
        }
      }
    )
  end

  def serialize_ticket_for_kanban(ticket)
    {
      id: ticket.id,
      title: ticket.title,
      description: ticket.description,
      status: ticket.status,
      priority: ticket.priority,
      is_feature_request: ticket.is_feature_request,
      conversation_id: ticket.conversation_id,
      account_id: ticket.account_id,
      conversation: ticket.conversation ? {
        id: ticket.conversation.id,
        display_id: ticket.conversation.display_id,
        status: ticket.conversation.status
      } : nil,
      contact: ticket.contact ? {
        id: ticket.contact.id,
        name: ticket.contact.name,
        email: ticket.contact.email
      } : nil,
      assigned_agent: ticket.assigned_agent ? {
        id: ticket.assigned_agent.id,
        name: ticket.assigned_agent.name,
        email: ticket.assigned_agent.email
      } : nil,
      created_by: ticket.created_by ? {
        id: ticket.created_by.id,
        name: ticket.created_by.name
      } : nil,
      created_at: ticket.created_at,
      updated_at: ticket.updated_at,
      jira_issue_key: ticket.jira_issue_key,
      jira_status: ticket.jira_status,
      jira_in_progress: ticket.jira_in_progress?,
      plane_issue_id: ticket.plane_issue_id,
      plane_issue_key: ticket.plane_issue_key,
      plane_state: ticket.plane_state,
      plane_in_progress: ticket.plane_in_progress?
    }
  end
end
