class Api::V1::Accounts::Reports::TicketsController < Api::V1::Accounts::BaseController
  before_action :check_authorization

  def index
    # Build base query with filters (this will be used for both metrics and pagination)
    base_query = current_account.tickets.includes(:conversation, :assigned_agent, :created_by)

    # Apply filters to base query
    base_query = base_query.where(status: params[:status]) if params[:status].present?
    base_query = base_query.where(priority: params[:priority]) if params[:priority].present?
    base_query = base_query.where(category: params[:category]) if params[:category].present?
    base_query = base_query.where(assigned_agent_id: params[:assigned_agent_id]) if params[:assigned_agent_id].present?
    if params[:from].present? && parse_timestamp(params[:from])
      base_query = base_query.where('created_at >= ?',
                                    parse_timestamp(params[:from]))
    end
    if params[:to].present? && parse_timestamp(params[:to])
      base_query = base_query.where('created_at <= ?',
                                    parse_timestamp(params[:to]))
    end

    # JIRA status filter
    if params[:jira_status].present?
      case params[:jira_status]
      when 'not_escalated'
        base_query = base_query.where(jira_issue_key: [nil, ''])
      when 'escalated'
        base_query = base_query.where.not(jira_issue_key: [nil, ''])
      end
    end

    # Calculate metrics on FULL filtered dataset (not paginated)
    @metrics = calculate_metrics(base_query)

    # Get total count from filtered dataset
    @total_count = base_query.count

    # Apply pagination ONLY to tickets for the table
    @tickets = base_query.page(params[:page] || 1).per(params[:per_page] || 25)

    # Set pagination headers
    response.headers['X-Total-Count'] = @total_count.to_s
    response.headers['X-Current-Page'] = @tickets.current_page.to_s
    response.headers['X-Per-Page'] = @tickets.limit_value.to_s
    response.headers['X-Total-Pages'] = @tickets.total_pages.to_s
  end

  def metrics
    @tickets = current_account.tickets

    # Apply filters
    @tickets = @tickets.where(status: params[:status]) if params[:status].present?
    @tickets = @tickets.where(priority: params[:priority]) if params[:priority].present?
    @tickets = @tickets.where(category: params[:category]) if params[:category].present?
    @tickets = @tickets.where(assigned_agent_id: params[:assigned_agent_id]) if params[:assigned_agent_id].present?
    if params[:from].present? && parse_timestamp(params[:from])
      @tickets = @tickets.where('created_at >= ?',
                                parse_timestamp(params[:from]))
    end
    if params[:to].present? && parse_timestamp(params[:to])
      @tickets = @tickets.where('created_at <= ?',
                                parse_timestamp(params[:to]))
    end

    # JIRA status filter
    if params[:jira_status].present?
      case params[:jira_status]
      when 'not_escalated'
        @tickets = @tickets.where(jira_issue_key: [nil, ''])
      when 'escalated'
        @tickets = @tickets.where.not(jira_issue_key: [nil, ''])
      end
    end

    # Calculate metrics
    metrics = calculate_metrics(@tickets)
    render json: metrics
  end

  def summary
    @tickets = current_account.tickets

    # Apply date filters
    if params[:from].present? && parse_timestamp(params[:from])
      @tickets = @tickets.where('created_at >= ?',
                                parse_timestamp(params[:from]))
    end
    if params[:to].present? && parse_timestamp(params[:to])
      @tickets = @tickets.where('created_at <= ?',
                                parse_timestamp(params[:to]))
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

    render json: {
      status_distribution: status_counts,
      priority_distribution: priority_counts,
      category_distribution: category_counts,
      escalation_data: {
        escalated: escalated_count,
        not_escalated: not_escalated_count
      }
    }
  end

  private

  def check_authorization
    authorize :report, :view?
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
end
