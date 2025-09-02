class Api::V1::Accounts::Reports::TicketsController < Api::V1::Accounts::BaseController
  before_action :check_authorization

  def index
    # Build base query with filters (this will be used for both metrics and pagination)
    base_query = current_account.tickets.includes(:conversation, :assigned_agent, :created_by)

    # Handle feature request filtering
    if params[:feature_requests_only] == 'true'
      # Show ONLY feature requests
      base_query = base_query.feature_requests
    elsif params[:include_feature_requests] == 'true'
      # Include both regular tickets and feature requests (no filtering)
    else
      # Default: exclude feature requests from reports
      base_query = base_query.regular_tickets
    end

    # Apply date filters first (always required for proper time-based analysis)
    if params[:from].present? && parse_timestamp(params[:from])
      base_query = base_query.where('created_at >= ?', parse_timestamp(params[:from]))
    else
      # Default to last 30 days if no start date provided
      base_query = base_query.where('created_at >= ?', 30.days.ago)
    end
    
    if params[:to].present? && parse_timestamp(params[:to])
      base_query = base_query.where('created_at <= ?', parse_timestamp(params[:to]))
    else
      # Default to current time if no end date provided
      base_query = base_query.where('created_at <= ?', Time.current)
    end

    # Apply other filters to base query
    base_query = base_query.where(status: params[:status]) if params[:status].present?
    base_query = base_query.where(priority: params[:priority]) if params[:priority].present?
    base_query = base_query.where(category: params[:category]) if params[:category].present?
    base_query = base_query.where(assigned_agent_id: params[:assigned_agent_id]) if params[:assigned_agent_id].present?

    # JIRA linking filter (simple linked vs unlinked)
    if params[:linked_with_jira].present?
      case params[:linked_with_jira]
      when 'true'
        # Only tickets with JIRA issue key
        base_query = base_query.where.not(jira_issue_key: [nil, ''])
      when 'false'
        # Only tickets without JIRA issue key
        base_query = base_query.where(jira_issue_key: [nil, ''])
      end
    end

    # JIRA status filter (only applies to linked tickets)
    if params[:jira_status].present?
      case params[:jira_status]
      when 'escalated'
        # Escalated tickets: status='escalated' AND jira_in_progress=false
        base_query = base_query.where(status: 'escalated')
                               .where(jira_in_progress: [false, nil])
      when 'in_progress'
        # In progress tickets: status='escalated' AND jira_in_progress=true
        base_query = base_query.where(status: 'escalated')
                               .where(jira_in_progress: true)
      when 'done'
        # Tickets that are resolved/closed
        base_query = base_query.where(status: ['resolved', 'closed'])
      end
    end

    # Calculate metrics on FULL filtered dataset (not paginated)
    @metrics = calculate_metrics(base_query)

    # Get total count from filtered dataset
    @total_count = base_query.count

    # Apply pagination ONLY to tickets for the table, ordered by ticket ID descending
    @tickets = base_query.order(id: :desc).page(params[:page] || 1).per(params[:per_page] || 25)

    # Set pagination headers
    response.headers['X-Total-Count'] = @total_count.to_s
    response.headers['X-Current-Page'] = @tickets.current_page.to_s
    response.headers['X-Per-Page'] = @tickets.limit_value.to_s
    response.headers['X-Total-Pages'] = @tickets.total_pages.to_s
  end

  def metrics
    @tickets = current_account.tickets

    # Handle feature request filtering
    if params[:feature_requests_only] == 'true'
      # Show ONLY feature requests
      @tickets = @tickets.feature_requests
    elsif params[:include_feature_requests] == 'true'
      # Include both regular tickets and feature requests (no filtering)
    else
      # Default: exclude feature requests from reports
      @tickets = @tickets.regular_tickets
    end

    # Apply date filters with defaults
    if params[:from].present? && parse_timestamp(params[:from])
      @tickets = @tickets.where('created_at >= ?', parse_timestamp(params[:from]))
    else
      # Default to last 30 days if no start date provided
      @tickets = @tickets.where('created_at >= ?', 30.days.ago)
    end
    
    if params[:to].present? && parse_timestamp(params[:to])
      @tickets = @tickets.where('created_at <= ?', parse_timestamp(params[:to]))
    else
      # Default to current time if no end date provided
      @tickets = @tickets.where('created_at <= ?', Time.current)
    end

    # Apply other filters
    @tickets = @tickets.where(status: params[:status]) if params[:status].present?
    @tickets = @tickets.where(priority: params[:priority]) if params[:priority].present?
    @tickets = @tickets.where(category: params[:category]) if params[:category].present?
    @tickets = @tickets.where(assigned_agent_id: params[:assigned_agent_id]) if params[:assigned_agent_id].present?

    # JIRA linking filter (simple linked vs unlinked)
    if params[:linked_with_jira].present?
      case params[:linked_with_jira]
      when 'true'
        # Only tickets with JIRA issue key
        @tickets = @tickets.where.not(jira_issue_key: [nil, ''])
      when 'false'
        # Only tickets without JIRA issue key
        @tickets = @tickets.where(jira_issue_key: [nil, ''])
      end
    end

    # JIRA status filter (only applies to linked tickets)
    if params[:jira_status].present?
      case params[:jira_status]
      when 'escalated'
        # Escalated tickets: status='escalated' AND jira_in_progress=false
        @tickets = @tickets.where(status: 'escalated')
                           .where(jira_in_progress: [false, nil])
      when 'in_progress'
        # In progress tickets: status='escalated' AND jira_in_progress=true
        @tickets = @tickets.where(status: 'escalated')
                           .where(jira_in_progress: true)
      when 'done'
        # Tickets that are resolved/closed
        @tickets = @tickets.where(status: ['resolved', 'closed'])
      end
    end

    # Calculate metrics
    metrics = calculate_metrics(@tickets)
    render json: metrics
  end

  def summary
    @tickets = current_account.tickets

    # Handle feature request filtering
    if params[:feature_requests_only] == 'true'
      # Show ONLY feature requests
      @tickets = @tickets.feature_requests
    elsif params[:include_feature_requests] == 'true'
      # Include both regular tickets and feature requests (no filtering)
    else
      # Default: exclude feature requests from reports
      @tickets = @tickets.regular_tickets
    end

    # Apply date filters with defaults
    if params[:from].present? && parse_timestamp(params[:from])
      @tickets = @tickets.where('created_at >= ?', parse_timestamp(params[:from]))
    else
      # Default to last 30 days if no start date provided
      @tickets = @tickets.where('created_at >= ?', 30.days.ago)
    end
    
    if params[:to].present? && parse_timestamp(params[:to])
      @tickets = @tickets.where('created_at <= ?', parse_timestamp(params[:to]))
    else
      # Default to current time if no end date provided
      @tickets = @tickets.where('created_at <= ?', Time.current)
    end

    # Apply other filters
    @tickets = @tickets.where(status: params[:status]) if params[:status].present?
    @tickets = @tickets.where(priority: params[:priority]) if params[:priority].present?
    @tickets = @tickets.where(category: params[:category]) if params[:category].present?
    @tickets = @tickets.where(assigned_agent_id: params[:assigned_agent_id]) if params[:assigned_agent_id].present?

    # JIRA linking filter (simple linked vs unlinked)
    if params[:linked_with_jira].present?
      case params[:linked_with_jira]
      when 'true'
        # Only tickets with JIRA issue key
        @tickets = @tickets.where.not(jira_issue_key: [nil, ''])
      when 'false'
        # Only tickets without JIRA issue key
        @tickets = @tickets.where(jira_issue_key: [nil, ''])
      end
    end

    # JIRA status filter (only applies to linked tickets)
    if params[:jira_status].present?
      case params[:jira_status]
      when 'escalated'
        # Escalated tickets: status='escalated' AND jira_in_progress=false
        @tickets = @tickets.where(status: 'escalated')
                           .where(jira_in_progress: [false, nil])
      when 'in_progress'
        # In progress tickets: status='escalated' AND jira_in_progress=true
        @tickets = @tickets.where(status: 'escalated')
                           .where(jira_in_progress: true)
      when 'done'
        # Tickets that are resolved/closed
        @tickets = @tickets.where(status: ['resolved', 'closed'])
      end
    end

    # Status distribution
    status_counts = @tickets.group(:status).count

    # Priority distribution
    priority_counts = @tickets.group(:priority).count

    # Category distribution
    category_counts = @tickets.group(:category).count

    # Escalation data
    escalated_count = @tickets.where.not(jira_issue_key: [nil, '']).count
    not_escalated_count = @tickets.where(jira_issue_key: [nil, '']).count

    # Resolution time trend data (group by date)
    resolved_tickets = @tickets.where(status: %i[resolved closed])
                               .where.not(resolved_at: nil)
                               .select(:resolved_at, :created_at)

    resolution_trend = {}
    resolved_tickets.each do |ticket|
      date = ticket.resolved_at.to_date.to_s
      resolution_time = (ticket.resolved_at - ticket.created_at).to_i
      
      if resolution_trend[date]
        resolution_trend[date][:total_time] += resolution_time
        resolution_trend[date][:count] += 1
      else
        resolution_trend[date] = { total_time: resolution_time, count: 1 }
      end
    end

    # Calculate average resolution time per date
    resolution_trend_avg = resolution_trend.transform_values do |data|
      data[:total_time] / data[:count]
    end

    # Escalation rate by priority
    escalation_by_priority = {}
    @tickets.group(:priority).count.each do |priority, total_in_priority|
      escalated_in_priority = @tickets.where(priority: priority).where.not(jira_issue_key: [nil, '']).count
      escalation_rate = total_in_priority > 0 ? ((escalated_in_priority.to_f / total_in_priority) * 100).round : 0
      
      escalation_by_priority[priority] = {
        total: total_in_priority,
        escalated: escalated_in_priority,
        escalation_rate: escalation_rate
      }
    end

    render json: {
      status_distribution: status_counts,
      priority_distribution: priority_counts,
      category_distribution: category_counts,
      escalation_data: {
        escalated: escalated_count,
        not_escalated: not_escalated_count
      },
      resolution_time_trend: resolution_trend_avg,
      escalation_by_priority: escalation_by_priority
    }
  end

  def download
    @tickets = current_account.tickets.includes({ conversation: :contact }, :assigned_agent, :created_by)

    # Handle feature request filtering
    if params[:feature_requests_only] == 'true'
      # Show ONLY feature requests
      @tickets = @tickets.feature_requests
    elsif params[:include_feature_requests] == 'true'
      # Include both regular tickets and feature requests (no filtering)
    else
      # Default: exclude feature requests from reports
      @tickets = @tickets.regular_tickets
    end

    # Apply date filters with defaults
    if params[:from].present? && parse_timestamp(params[:from])
      @tickets = @tickets.where('created_at >= ?', parse_timestamp(params[:from]))
    else
      # Default to last 30 days if no start date provided
      @tickets = @tickets.where('created_at >= ?', 30.days.ago)
    end
    
    if params[:to].present? && parse_timestamp(params[:to])
      @tickets = @tickets.where('created_at <= ?', parse_timestamp(params[:to]))
    else
      # Default to current time if no end date provided
      @tickets = @tickets.where('created_at <= ?', Time.current)
    end

    # Apply other filters
    @tickets = @tickets.where(status: params[:status]) if params[:status].present?
    @tickets = @tickets.where(priority: params[:priority]) if params[:priority].present?
    @tickets = @tickets.where(category: params[:category]) if params[:category].present?
    @tickets = @tickets.where(assigned_agent_id: params[:assigned_agent_id]) if params[:assigned_agent_id].present?

    # JIRA linking filter (simple linked vs unlinked)
    if params[:linked_with_jira].present?
      case params[:linked_with_jira]
      when 'true'
        # Only tickets with JIRA issue key
        @tickets = @tickets.where.not(jira_issue_key: [nil, ''])
      when 'false'
        # Only tickets without JIRA issue key
        @tickets = @tickets.where(jira_issue_key: [nil, ''])
      end
    end

    # JIRA status filter (only applies to linked tickets)
    if params[:jira_status].present?
      case params[:jira_status]
      when 'escalated'
        # Escalated tickets: status='escalated' AND jira_in_progress=false
        @tickets = @tickets.where(status: 'escalated')
                           .where(jira_in_progress: [false, nil])
      when 'in_progress'
        # In progress tickets: status='escalated' AND jira_in_progress=true
        @tickets = @tickets.where(status: 'escalated')
                           .where(jira_in_progress: true)
      when 'done'
        # Tickets that are resolved/closed
        @tickets = @tickets.where(status: ['resolved', 'closed'])
      end
    end

    # Generate CSV content
    csv_data = generate_tickets_csv(@tickets)
    
    send_data csv_data, 
              filename: "tickets-report-#{Date.current.strftime('%Y%m%d')}.csv",
              type: 'text/csv; charset=utf-8',
              disposition: 'attachment'
  end

  private

  def check_authorization
    authorize :report, :view?
  end

  def generate_tickets_csv(tickets)
    require 'csv'
    
    # Create a BOM for proper UTF-8 encoding
    bom = "\uFEFF"
    
    csv_content = CSV.generate(headers: true, encoding: 'UTF-8') do |csv|
      # CSV headers
      csv << [
        'Ticket ID',
        'Title',
        'Description',
        'Status',
        'Priority',
        'Category',
        'Type',
        'Created Date',
        'Updated Date',
        'Resolved Date',
        'Assigned Agent',
        'Created By',
        'Resolution Time (Hours)',
        'JIRA Issue Key',
        'JIRA Status',
        'Contact Name',
        'Contact Email',
        'Contact Organization',
        'Linked Messages Count',
        'Linked Messages Content'
      ]
      
      # Data rows
      tickets.find_each do |ticket|
        resolution_time = nil
        if ticket.resolved_at.present?
          resolution_time = ((ticket.resolved_at - ticket.created_at) / 1.hour).round(2)
        end
        
        jira_status = if ticket.jira_issue_key.present?
          if ticket.status == 'escalated' && ticket.jira_in_progress?
            'In Progress'
          elsif ticket.status == 'escalated'
            'Escalated'
          elsif ['resolved', 'closed'].include?(ticket.status)
            'Done'
          else
            'Unknown'
          end
        else
          'Not Linked'
        end
        
        # Get linked messages content
        linked_messages_content = get_linked_messages_content_for_export(ticket)
        linked_messages_count = ticket.ticket_messages.count
        
        csv << [
          ticket.id,
          ticket.title,
          ticket.description,
          ticket.status&.humanize,
          ticket.priority&.humanize,
          ticket.category,
          ticket.is_feature_request? ? 'Feature Request' : 'Regular Ticket',
          ticket.created_at&.strftime('%Y-%m-%d %H:%M:%S'),
          ticket.updated_at&.strftime('%Y-%m-%d %H:%M:%S'),
          ticket.resolved_at&.strftime('%Y-%m-%d %H:%M:%S'),
          ticket.assigned_agent&.name,
          ticket.created_by&.name,
          resolution_time,
          ticket.jira_issue_key,
          jira_status,
          ticket.safe_conversation&.contact&.name,
          ticket.safe_conversation&.contact&.email,
          ticket.safe_conversation&.contact&.additional_attributes&.dig('company_name') || 
            ticket.safe_conversation&.contact&.additional_attributes&.dig('companyName') || 
            ticket.safe_conversation&.contact&.custom_attributes&.dig('company_name') || 
            ticket.safe_conversation&.contact&.custom_attributes&.dig('companyName') ||
            ticket.safe_conversation&.contact&.custom_attributes&.dig('organization') || 
            ticket.safe_conversation&.contact&.additional_attributes&.dig('organization') ||
            'N/A',
          linked_messages_count,
          linked_messages_content
        ]
      end
    end
    
    # Prepend BOM for proper UTF-8 encoding in Excel
    bom + csv_content
  end

  def calculate_metrics(tickets_query)
    # Calculate metrics on the full filtered dataset
    total_tickets = tickets_query.count
    escalated_tickets = tickets_query.where.not(jira_issue_key: [nil, '']).count
    resolved_after_escalation = tickets_query.where(status: %i[resolved
                                                               closed]).where.not(jira_issue_key: [nil, '']).count

    # Calculate average resolution time
    resolved_with_times = tickets_query.where(status: %i[resolved closed])
                                       .where.not(resolved_at: nil)

    avg_resolution_time = 0
    if resolved_with_times.any?
      total_time = resolved_with_times.sum do |ticket|
        (ticket.resolved_at - ticket.created_at).to_i
      end
      avg_resolution_time = total_time / resolved_with_times.count
    end

    {
      total_tickets: total_tickets,
      avg_resolution_time: avg_resolution_time,
      escalation_percentage: total_tickets > 0 ? ((escalated_tickets.to_f / total_tickets) * 100).round : 0,
      resolved_after_escalation: escalated_tickets > 0 ? ((resolved_after_escalation.to_f / escalated_tickets) * 100).round : 0
    }
  end

  def parse_timestamp(timestamp_param)
    return nil if timestamp_param.blank?

    timestamp = timestamp_param.to_i
    # Check if it's a reasonable Unix timestamp (between 1970 and 2100)
    if timestamp > 0 && timestamp < 4_102_444_800 # Jan 1, 2100
      Time.zone.at(timestamp)
    else
      # Fallback to parsing as a date string
      Time.zone.parse(timestamp_param)
    end
  rescue ArgumentError
    # If all else fails, return nil
    nil
  end

  def get_linked_messages_content_for_export(ticket)
    # Get linked messages for the ticket
    linked_messages = ticket.ticket_messages
                            .includes(message: %i[sender conversation])
                            .joins(:message)
                            .order('messages.created_at ASC')
                            .map(&:message)

    return '' if linked_messages.empty?

    # Format messages for export with proper encoding
    messages_content = linked_messages.map do |message|
      sender_type = message.incoming? ? 'Customer' : 'Agent'
      sender_name = message.sender&.name || 'Unknown'
      timestamp = message.created_at.strftime('%Y-%m-%d %H:%M:%S')
      content = message.content || ''
      
      # Clean up content for CSV export
      clean_content = content.gsub(/[\r\n]+/, ' ').gsub(/\s+/, ' ').strip
      
      "[#{timestamp}] #{sender_type} (#{sender_name}): #{clean_content}"
    end

    messages_content.join(' | ')
  end
end
