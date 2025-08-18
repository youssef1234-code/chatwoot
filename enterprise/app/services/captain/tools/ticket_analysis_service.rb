class Captain::Tools::TicketAnalysisService < Captain::Tools::BaseService
  def name
    'ticket_analysis'
  end

  def description
    current_date = Date.current.strftime('%Y-%m-%d')
    'Analyze tickets with various filtering options and generate summaries, insights, and statistics. Use "customer_messages" analysis type to retrieve actual messages sent by customers linked to tickets. Current date is ' + current_date + '. Use this for date-relative queries like "today", "this week", etc.'
  end

  def parameters
    {
      type: 'object',
      properties: {
        analysis_type: {
          type: 'string',
          enum: ['summary', 'status_distribution', 'priority_analysis', 'category_trends', 
                 'resolution_times', 'escalation_analysis', 'feature_requests', 'agent_performance', 
                 'customer_messages', 'recent_issues', 'detailed_tickets', 'time_analysis', 'custom'],
          description: 'Type of analysis to perform'
        },
        date_range: {
          type: 'object',
          properties: {
            from: {
              type: 'string',
              description: 'Start date in YYYY-MM-DD format (defaults to 30 days ago)'
            },
            to: {
              type: 'string', 
              description: 'End date in YYYY-MM-DD format (defaults to today)'
            }
          }
        },
        filters: {
          type: 'object',
          properties: {
            status: {
              type: 'string',
              enum: ['open', 'in_progress', 'escalated', 'resolved', 'closed'],
              description: 'Filter by ticket status'
            },
            priority: {
              type: 'string',
              enum: ['low', 'medium', 'high', 'urgent'],
              description: 'Filter by ticket priority'
            },
            category: {
              type: 'string',
              description: 'Filter by ticket category'
            },
            assigned_agent_id: {
              type: 'integer',
              description: 'Filter by assigned agent ID'
            },
            ticket_type: {
              type: 'string',
              enum: ['regular', 'feature_requests', 'all'],
              description: 'Filter by ticket type (regular tickets, feature requests, or all)'
            },
            jira_linked: {
              type: 'boolean',
              description: 'Filter by JIRA integration status'
            }
          }
        },
        limit: {
          type: 'integer',
          description: 'Maximum number of tickets to analyze (defaults to 1000, no maximum limit)',
          minimum: 1
        }
      },
      required: ['analysis_type']
    }
  end

  def execute(arguments)
    Rails.logger.info { "#{self.class.name}: Executing #{arguments['analysis_type']} analysis" }

    # Check permissions
    unless user_has_permission('tickets_view')
      return 'Access denied: You do not have permission to view tickets.'
    end

    analysis_type = arguments['analysis_type']
    date_range = arguments['date_range'] || {}
    filters = arguments['filters'] || {}
    limit = arguments['limit'] || 1000  # Increased default, no maximum limit

    # Build the base ticket query
    tickets_query = build_tickets_query(date_range, filters, limit)
    
    case analysis_type
    when 'summary'
      generate_summary(tickets_query)
    when 'status_distribution'
      analyze_status_distribution(tickets_query)
    when 'priority_analysis'
      analyze_priority_distribution(tickets_query)
    when 'category_trends'
      analyze_category_trends(tickets_query)
    when 'resolution_times'
      analyze_resolution_times(tickets_query)
    when 'escalation_analysis'
      analyze_escalations(tickets_query)
    when 'feature_requests'
      analyze_feature_requests(tickets_query)
    when 'agent_performance'
      analyze_agent_performance(tickets_query)
    when 'customer_messages'
      analyze_customer_messages(tickets_query, arguments)
    when 'recent_issues'
      analyze_recent_issues(tickets_query, arguments)
    when 'detailed_tickets'
      generate_detailed_tickets_report(tickets_query, arguments)
    when 'time_analysis'
      analyze_time_patterns(tickets_query)
    when 'custom'
      generate_custom_analysis(tickets_query, arguments)
    else
      'Invalid analysis type specified.'
    end
  rescue StandardError => e
    Rails.logger.error { "#{self.class.name}: Error executing analysis: #{e.message}" }
    "Error performing ticket analysis: #{e.message}"
  end

  def active?
    # Only activate if user has ticket viewing permissions
    user_has_permission('tickets_view')
  end

  def analyze_customer_messages(tickets_query, arguments)
    tickets = tickets_query.includes(:conversation, :ticket_messages, 
                                     conversation: [:contact, :messages], 
                                     ticket_messages: :message).to_a
    
    return 'No tickets found for customer message analysis.' if tickets.empty?

    # Get date filter for analysis
    date_filter = arguments.dig('date_range', 'from') || arguments.dig('date_range', 'to')
    time_frame = if date_filter
      if arguments.dig('date_range', 'from') == Date.current.strftime('%Y-%m-%d')
        'today'
      elsif arguments.dig('date_range', 'from') == Date.current.beginning_of_month.strftime('%Y-%m-%d')
        'this month'
      else
        'the specified time period'
      end
    else
      'all time'
    end

    # Analyze customer messages and ticket content
    issues_summary = []
    feature_requests_summary = []
    
    tickets.each do |ticket|
      begin
        ticket_summary = {
          id: ticket.id,
          title: ticket.title,
          description: ticket.description,
          status: ticket.status,
          priority: ticket.priority,
          category: ticket.category,
          created_at: ticket.created_at,
          conversation_id: ticket.conversation_id,
          customer_name: ticket.conversation&.contact&.name,
          customer_email: ticket.conversation&.contact&.email,
          is_feature_request: ticket.is_feature_request?,
          messages: [],
          ticket_messages: []
        }

        # Get customer messages from conversation - Focus on customer (incoming) messages
        if ticket.conversation.present?
          begin
            # Get all messages from the conversation, focusing on customer messages
            all_messages = ticket.conversation.messages
                                      .where(private: false)
                                      .order(:created_at)
                                      .limit(20) # Get more messages for better context

            # Separate customer messages from agent messages
            customer_messages = all_messages.where(message_type: 'incoming')
            agent_messages = all_messages.where(message_type: 'outgoing')

            # Include both customer and agent messages for full context
            ticket_summary[:messages] = all_messages.map do |msg|
              {
                content: msg.content&.strip || 'No content',
                message_type: msg.message_type,
                created_at: msg.created_at,
                sender: msg.sender&.name || (msg.message_type == 'incoming' ? 'Customer' : 'Agent'),
                is_customer_message: msg.message_type == 'incoming'
              }
            end

            # Also store just customer messages for easier analysis
            ticket_summary[:customer_messages_only] = customer_messages.map do |msg|
              {
                content: msg.content&.strip || 'No content',
                created_at: msg.created_at,
                sender: msg.sender&.name || 'Customer'
              }
            end

            Rails.logger.info "Ticket #{ticket.id}: Found #{customer_messages.count} customer messages and #{agent_messages.count} agent messages"
          rescue => e
            Rails.logger.error "Error accessing conversation messages for ticket #{ticket.id}: #{e.message}"
            ticket_summary[:messages] = [{ content: "Unable to access conversation messages: #{e.message}", message_type: "error" }]
            ticket_summary[:customer_messages_only] = []
          end
        else
          Rails.logger.warn "Ticket #{ticket.id} has no associated conversation"
          ticket_summary[:messages] = [{ content: "No conversation linked to this ticket", message_type: "info" }]
          ticket_summary[:customer_messages_only] = []
        end

        # Get linked messages through ticket_messages
        if ticket.ticket_messages.present?
          begin
            ticket_summary[:ticket_messages] = ticket.ticket_messages.includes(:message).map do |ticket_msg|
              if ticket_msg.message.present?
                {
                  content: ticket_msg.message.content&.strip || 'No content',
                  message_type: ticket_msg.message.message_type,
                  created_at: ticket_msg.message.created_at,
                  sender: ticket_msg.message.sender&.name || 'System'
                }
              else
                { content: "Message not available", message_type: "unavailable" }
              end
            end
          rescue => e
            Rails.logger.error "Error accessing ticket messages for ticket #{ticket.id}: #{e.message}"
            ticket_summary[:ticket_messages] = [{ content: "Unable to access ticket messages: #{e.message}", message_type: "error" }]
          end
        end

        if ticket.is_feature_request?
          feature_requests_summary << ticket_summary
        else
          issues_summary << ticket_summary
        end
      rescue => e
        Rails.logger.error "Error processing ticket #{ticket.id}: #{e.message}"
        # Continue with next ticket instead of failing completely
        next
      end
    end

    # Build comprehensive analysis with actual customer messages
    analysis = generate_date_context(arguments['date_range'] || {})
    
    analysis += """
💬 **Customer Messages Analysis for #{time_frame}**

**Overview:**
- Total Tickets Analyzed: #{tickets.count}
- Customer Issues: #{issues_summary.count}
- Feature Requests: #{feature_requests_summary.count}
- Tickets with Customer Messages: #{(issues_summary + feature_requests_summary).count { |t| t[:customer_messages_only]&.any? }}

"""

    # Detailed issues analysis with actual customer messages
    if issues_summary.any?
      analysis += "\n**🔴 Customer Issues & Their Messages:**\n"
      issues_summary.each_with_index do |ticket, index|
        analysis += """
#{index + 1}. **#{ticket[:title]}** (#{ticket[:status]&.humanize}, #{ticket[:priority]&.humanize} priority)
   - **Ticket ID:** #{ticket[:id]} | **Conversation ID:** #{ticket[:conversation_id] || 'Not linked'}
   - Customer: #{ticket[:customer_name]} (#{ticket[:customer_email]})
   - Created: #{ticket[:created_at]&.strftime('%Y-%m-%d %H:%M')}
   - Category: #{ticket[:category] || 'Uncategorized'}
"""

        # Show actual customer messages with IDs
        if ticket[:customer_messages_only]&.any?
          analysis += "   - **📝 What the Customer Actually Said:**\n"
          ticket[:customer_messages_only].each_with_index do |msg, msg_idx|
            timestamp = msg[:created_at]&.strftime('%m/%d %H:%M') || 'Unknown time'
            analysis += "     #{msg_idx + 1}. [#{timestamp}] (Message ID: #{msg[:id]}) \"#{msg[:content]}\"\n"
          end
          analysis += "   - **💡 For detailed messages:** Use 'get_ticket_messages' tool with ticket ID #{ticket[:id]}\n"
        else
          analysis += "   - **📝 Customer Messages:** No direct customer messages found\n"
        end

        # Show conversation context if available
        if ticket[:messages]&.any? && !ticket[:messages].first[:content].include?("Unable to access")
          customer_msg_count = ticket[:messages].count { |m| m[:is_customer_message] }
          agent_msg_count = ticket[:messages].count { |m| !m[:is_customer_message] }
          analysis += "   - **💬 Conversation Summary:** #{customer_msg_count} customer messages, #{agent_msg_count} agent responses\n"
        end

        # Fallback to ticket description if no messages
        if ticket[:customer_messages_only]&.empty? && ticket[:messages]&.empty?
          analysis += "   - **📄 Issue Description:** #{ticket[:description] || 'No details available'}\n"
        end
        
        analysis += "\n"
      end
    end

    # Feature requests analysis with customer messages
    if feature_requests_summary.any?
      analysis += "\n**💡 Feature Requests & Customer Input:**\n"
      feature_requests_summary.each_with_index do |ticket, index|
        analysis += """
#{index + 1}. **#{ticket[:title]}** (#{ticket[:status]&.humanize})
   - **Ticket ID:** #{ticket[:id]} | **Conversation ID:** #{ticket[:conversation_id] || 'Not linked'}
   - Requested by: #{ticket[:customer_name]} (#{ticket[:customer_email]})
   - Created: #{ticket[:created_at]&.strftime('%Y-%m-%d %H:%M')}
"""

        # Show customer's actual feature request messages with IDs
        if ticket[:customer_messages_only]&.any?
          analysis += "   - **💡 Customer's Feature Request Details:**\n"
          ticket[:customer_messages_only].each_with_index do |msg, msg_idx|
            timestamp = msg[:created_at]&.strftime('%m/%d %H:%M') || 'Unknown time'
            analysis += "     #{msg_idx + 1}. [#{timestamp}] (Message ID: #{msg[:id]}) \"#{msg[:content]}\"\n"
          end
          analysis += "   - **💡 For detailed messages:** Use 'get_ticket_messages' tool with ticket ID #{ticket[:id]}\n"
        else
          analysis += "   - **💡 Request Details:** #{ticket[:description] || 'No direct customer messages found'}\n"
        end
        analysis += "\n"
      end
    end

    # Add comprehensive message statistics
    total_customer_messages = (issues_summary + feature_requests_summary).sum { |t| t[:customer_messages_only]&.count || 0 }
    total_conversation_messages = (issues_summary + feature_requests_summary).sum { |t| t[:messages]&.count || 0 }
    
    analysis += "\n**📊 Message Access Summary:**\n"
    analysis += "- Total customer messages retrieved: #{total_customer_messages}\n"
    analysis += "- Total conversation messages: #{total_conversation_messages}\n"
    analysis += "- Tickets with linked conversations: #{tickets.count { |t| t.conversation_id.present? }}\n"
    analysis += "- Successful message access rate: #{tickets.count > 0 ? ((tickets.count { |t| t.conversation.present? }).to_f / tickets.count * 100).round(1) : 0}%\n"

    analysis
  rescue => e
    Rails.logger.error "Error in analyze_customer_messages: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    "Error analyzing customer messages: #{e.message}. Please check the logs for more details."
  end

  def analyze_recent_issues(tickets_query, arguments)
    # Focus on recent tickets (last 7 days by default, or today if specified)
    recent_tickets = if arguments.dig('date_range', 'from') == Date.current.strftime('%Y-%m-%d')
                       tickets_query.where('tickets.created_at >= ?', Date.current.beginning_of_day)
                     else
                       tickets_query.where('tickets.created_at >= ?', 7.days.ago)
                     end.to_a

    return 'No recent issues found.' if recent_tickets.empty?

    time_frame = arguments.dig('date_range', 'from') == Date.current.strftime('%Y-%m-%d') ? 'today' : 'the last 7 days'

    analysis = """
🕐 **Recent Issues Analysis - #{time_frame}**

**Summary:**
- Total Recent Tickets: #{recent_tickets.count}
- Open Issues: #{recent_tickets.count { |t| ['open', 'in_progress'].include?(t.status) }}
- Resolved: #{recent_tickets.count { |t| ['resolved', 'closed'].include?(t.status) }}
- High Priority: #{recent_tickets.count { |t| ['high', 'urgent'].include?(t.priority) }}

**Recent Issues by Priority:**
"""

    # Group by priority
    priority_groups = recent_tickets.group_by(&:priority)
    
    ['urgent', 'high', 'medium', 'low'].each do |priority|
      tickets_in_priority = priority_groups[priority] || []
      next if tickets_in_priority.empty?

      analysis += "\n**#{priority&.humanize} Priority (#{tickets_in_priority.count} tickets):**\n"
      
      tickets_in_priority.first(5).each do |ticket| # Show first 5 in each priority
        analysis += """- **#{ticket.title}** (#{ticket.status&.humanize})
  Category: #{ticket.category || 'Uncategorized'} | Customer: #{ticket.conversation&.contact&.name}
  Created: #{ticket.created_at&.strftime('%Y-%m-%d %H:%M')}
  #{ticket.description&.truncate(100) || 'No description'}

"""
      end
    end

    analysis
  end

  def generate_detailed_tickets_report(tickets_query, arguments)
    tickets = tickets_query.includes(:conversation, :assigned_agent, :created_by, 
                                     conversation: :contact).to_a
    
    return 'No tickets found for detailed report.' if tickets.empty?

    limit = arguments['limit'] || 20  # Default to 20 for detailed view
    tickets = tickets.first(limit) if tickets.count > limit

    analysis = """
📋 **Detailed Tickets Report**

**Showing #{tickets.count} tickets with complete information:**

"""

    tickets.each_with_index do |ticket, index|
      jira_status = if ticket.jira_issue_key.present?
        if ticket.status == 'escalated' && ticket.jira_in_progress?
          'In Progress'
        elsif ticket.status == 'escalated'
          'Escalated'
        elsif ['resolved', 'closed'].include?(ticket.status)
          'Done'
        else
          'Linked'
        end
      else
        'Not Linked'
      end

      resolution_time = if ticket.resolved_at.present?
        hours = ((ticket.resolved_at - ticket.created_at) / 1.hour).round(2)
        "#{hours} hours"
      else
        'Not resolved'
      end

      analysis += """
**#{index + 1}. Ticket ##{ticket.id}**
- **Title:** #{ticket.title}
- **Type:** #{ticket.is_feature_request? ? 'Feature Request' : 'Regular Ticket'}
- **Status:** #{ticket.status&.humanize}
- **Priority:** #{ticket.priority&.humanize}
- **Category:** #{ticket.category || 'Uncategorized'}
- **Created:** #{ticket.created_at&.strftime('%Y-%m-%d %H:%M:%S')}
- **Updated:** #{ticket.updated_at&.strftime('%Y-%m-%d %H:%M:%S')}
- **Resolved:** #{ticket.resolved_at&.strftime('%Y-%m-%d %H:%M:%S') || 'Not resolved'}
- **Resolution Time:** #{resolution_time}
- **Customer:** #{ticket.conversation&.contact&.name} (#{ticket.conversation&.contact&.email})
- **Assigned Agent:** #{ticket.assigned_agent&.name || 'Unassigned'}
- **Created By:** #{ticket.created_by&.name}
- **JIRA Status:** #{jira_status}
- **JIRA Issue:** #{ticket.jira_issue_key || 'None'}
- **Description:** #{ticket.description || 'No description provided'}

"""
    end

    analysis
  end

  def analyze_time_patterns(tickets_query)
    tickets = tickets_query.to_a
    
    return 'No tickets found for time pattern analysis.' if tickets.empty?

    # Analyze creation patterns
    hourly_creation = tickets.group_by { |t| t.created_at.hour }.transform_values(&:count)
    daily_creation = tickets.group_by { |t| t.created_at.strftime('%A') }.transform_values(&:count)
    monthly_creation = tickets.group_by { |t| t.created_at.strftime('%Y-%m') }.transform_values(&:count)

    # Resolution time patterns
    resolved_tickets = tickets.select { |t| t.resolved_at.present? }
    resolution_by_priority = resolved_tickets.group_by(&:priority).transform_values do |priority_tickets|
      times = priority_tickets.map { |t| (t.resolved_at - t.created_at) / 1.hour }
      {
        count: times.count,
        avg_hours: times.sum / times.count,
        min_hours: times.min,
        max_hours: times.max
      }
    end

    analysis = """
⏰ **Time Patterns Analysis**

**Creation Patterns:**

**By Hour of Day:**
#{hourly_creation.sort.map { |hour, count| "#{hour}:00 - #{count} tickets" }.join("\n")}

**By Day of Week:**
#{daily_creation.map { |day, count| "#{day}: #{count} tickets" }.join("\n")}

**By Month:**
#{monthly_creation.sort.map { |month, count| "#{month}: #{count} tickets" }.join("\n")}

**Resolution Time by Priority:**
#{resolution_by_priority.map do |priority, data|
  "#{priority&.humanize || 'No Priority'}: #{data[:count]} tickets, Avg: #{data[:avg_hours].round(2)}h, Range: #{data[:min_hours].round(2)}h - #{data[:max_hours].round(2)}h"
end.join("\n")}

**Peak Hours:** #{hourly_creation.max_by { |_, count| count }[0]}:00 (#{hourly_creation.max_by { |_, count| count }[1]} tickets)
**Peak Day:** #{daily_creation.max_by { |_, count| count }[0]} (#{daily_creation.max_by { |_, count| count }[1]} tickets)
"""

    analysis
  end

  private

  def build_tickets_query(date_range, filters, limit)
    tickets = assistant.account.tickets.includes(:conversation, :assigned_agent, :created_by, 
                                                  :ticket_messages, 
                                                  conversation: [:contact, :messages],
                                                  ticket_messages: [:message])

    # Apply date filters - if no dates specified, get ALL tickets (not just last 30 days)
    if date_range['from'].present?
      from_date = Date.parse(date_range['from'])
      tickets = tickets.where('tickets.created_at >= ?', from_date.beginning_of_day)
    end
    
    if date_range['to'].present?
      to_date = Date.parse(date_range['to'])
      tickets = tickets.where('tickets.created_at <= ?', to_date.end_of_day)
    end

    # Apply ticket type filter
    case filters['ticket_type']
    when 'feature_requests'
      tickets = tickets.feature_requests
    when 'regular'
      tickets = tickets.regular_tickets
    # 'all' or nil means no filtering on ticket type
    end

    # Apply other filters
    tickets = tickets.where(status: filters['status']) if filters['status'].present?
    tickets = tickets.where(priority: filters['priority']) if filters['priority'].present?
    tickets = tickets.where(category: filters['category']) if filters['category'].present?
    tickets = tickets.where(assigned_agent_id: filters['assigned_agent_id']) if filters['assigned_agent_id'].present?

    # Apply JIRA filter
    if filters['jira_linked'] == true
      tickets = tickets.where.not(jira_issue_key: [nil, ''])
    elsif filters['jira_linked'] == false
      tickets = tickets.where(jira_issue_key: [nil, ''])
    end

    # Apply limit only if specified, otherwise return all matching tickets
    limit > 0 ? tickets.limit(limit) : tickets
  end

  def generate_summary(tickets_query)
    tickets = tickets_query.includes(:conversation, :assigned_agent, :created_by, 
                                     conversation: :contact).to_a
    total_count = tickets.count
    
    return 'No tickets found matching the specified criteria.' if total_count.zero?

    # Basic metrics
    status_counts = tickets.group_by(&:status).transform_values(&:count)
    priority_counts = tickets.group_by(&:priority).transform_values(&:count)
    category_counts = tickets.group_by(&:category).transform_values(&:count)
    feature_requests_count = tickets.count(&:is_feature_request?)
    regular_tickets_count = total_count - feature_requests_count

    # Time-based metrics
    today_tickets = tickets.select { |t| t.created_at >= Date.current.beginning_of_day }
    this_week_tickets = tickets.select { |t| t.created_at >= 1.week.ago }
    this_month_tickets = tickets.select { |t| t.created_at >= 1.month.ago }

    # Resolution metrics
    resolved_tickets = tickets.select { |t| ['resolved', 'closed'].include?(t.status) && t.resolved_at.present? }
    avg_resolution_time = if resolved_tickets.any?
      total_time = resolved_tickets.sum { |t| (t.resolved_at - t.created_at).to_i }
      (total_time / resolved_tickets.count / 1.hour).round(2)
    else
      0
    end

    # Agent metrics
    agent_stats = tickets.group_by(&:assigned_agent).transform_values(&:count)
    unassigned_count = agent_stats[nil] || 0

    # Escalation metrics
    escalated_count = tickets.count { |t| t.jira_issue_key.present? }
    escalation_rate = total_count > 0 ? ((escalated_count.to_f / total_count) * 100).round(1) : 0

    # Customer metrics
    unique_customers = tickets.map { |t| t.conversation&.contact }.compact.uniq.count

    # Recent activity
    recent_tickets = tickets.select { |t| t.created_at >= 24.hours.ago }
    recent_high_priority = tickets.select { |t| ['high', 'urgent'].include?(t.priority) && t.created_at >= 24.hours.ago }

    summary = generate_date_context

    summary += """
📊 **Comprehensive Ticket Analysis Summary**

**📈 Overall Metrics:**
- Total Tickets: #{total_count}
- Regular Tickets: #{regular_tickets_count}
- Feature Requests: #{feature_requests_count}
- Unique Customers: #{unique_customers}

**📅 Time-based Breakdown:**
- Today: #{today_tickets.count} tickets
- This Week: #{this_week_tickets.count} tickets  
- This Month: #{this_month_tickets.count} tickets
- Last 24 Hours: #{recent_tickets.count} tickets

**📊 Status Distribution:**
#{status_counts.map { |status, count| "- #{status&.humanize}: #{count} (#{((count.to_f / total_count) * 100).round(1)}%)" }.join("\n")}

**🔥 Priority Distribution:**
#{priority_counts.map { |priority, count| "- #{priority&.humanize || 'No Priority'}: #{count} (#{((count.to_f / total_count) * 100).round(1)}%)" }.join("\n")}

**📋 Category Breakdown:**
#{category_counts.sort_by { |_, count| -count }.first(10).map { |category, count| "- #{category || 'Uncategorized'}: #{count} (#{((count.to_f / total_count) * 100).round(1)}%)" }.join("\n")}

**👥 Agent Assignment:**
- Assigned: #{total_count - unassigned_count} tickets
- Unassigned: #{unassigned_count} tickets
#{agent_stats.reject { |agent, _| agent.nil? }.sort_by { |_, count| -count }.first(5).map { |agent, count| "- #{agent.name}: #{count} tickets" }.join("\n")}

**⏱️ Resolution Metrics:**
- Resolved/Closed: #{resolved_tickets.count} tickets (#{((resolved_tickets.count.to_f / total_count) * 100).round(1)}%)
- Average Resolution Time: #{avg_resolution_time} hours
- Open Issues: #{status_counts['open'] || 0} tickets
- In Progress: #{status_counts['in_progress'] || 0} tickets

**🚨 Escalation Metrics:**
- Escalated to JIRA: #{escalated_count} tickets (#{escalation_rate}%)
- Non-escalated: #{total_count - escalated_count} tickets

**⚡ Recent Activity (Last 24h):**
- New Tickets: #{recent_tickets.count}
- High Priority Issues: #{recent_high_priority.count}

**🔍 Key Insights:**
#{generate_comprehensive_insights(tickets, status_counts, priority_counts, escalation_rate, avg_resolution_time, recent_tickets, recent_high_priority)}
"""

    summary
  end

  def analyze_status_distribution(tickets_query)
    tickets = tickets_query.to_a
    total_count = tickets.count
    
    return 'No tickets found for status analysis.' if total_count.zero?

    status_counts = tickets.group_by(&:status).transform_values(&:count)
    
    analysis = """
📈 **Status Distribution Analysis**

**Current Status Breakdown:**
#{status_counts.map do |status, count|
  percentage = ((count.to_f / total_count) * 100).round(1)
  "- #{status.humanize}: #{count} tickets (#{percentage}%)"
end.join("\n")}

**Analysis:**
- Most common status: #{status_counts.max_by { |_, count| count }[0].humanize}
- Open/In Progress tickets: #{(status_counts['open'] || 0) + (status_counts['in_progress'] || 0)}
- Resolved tickets: #{(status_counts['resolved'] || 0) + (status_counts['closed'] || 0)}
- Resolution rate: #{(((status_counts['resolved'] || 0) + (status_counts['closed'] || 0)).to_f / total_count * 100).round(1)}%
"""

    analysis
  end

  def analyze_priority_distribution(tickets_query)
    tickets = tickets_query.to_a
    total_count = tickets.count
    
    return 'No tickets found for priority analysis.' if total_count.zero?

    priority_counts = tickets.group_by(&:priority).transform_values(&:count)
    
    analysis = """
🔴 **Priority Distribution Analysis**

**Priority Breakdown:**
#{priority_counts.map do |priority, count|
  percentage = ((count.to_f / total_count) * 100).round(1)
  "- #{priority&.humanize || 'No Priority'}: #{count} tickets (#{percentage}%)"
end.join("\n")}

**High Priority Focus:**
- Urgent tickets: #{priority_counts['urgent'] || 0}
- High priority tickets: #{priority_counts['high'] || 0}
- Critical issues (Urgent + High): #{(priority_counts['urgent'] || 0) + (priority_counts['high'] || 0)} (#{(((priority_counts['urgent'] || 0) + (priority_counts['high'] || 0)).to_f / total_count * 100).round(1)}%)
"""

    analysis
  end

  def analyze_category_trends(tickets_query)
    tickets = tickets_query.to_a
    total_count = tickets.count
    
    return 'No tickets found for category analysis.' if total_count.zero?

    category_counts = tickets.group_by(&:category).transform_values(&:count)
    
    analysis = """
📋 **Category Trends Analysis**

**Category Distribution:**
#{category_counts.map do |category, count|
  percentage = ((count.to_f / total_count) * 100).round(1)
  "- #{category || 'Uncategorized'}: #{count} tickets (#{percentage}%)"
end.join("\n")}

**Top Categories:**
#{category_counts.sort_by { |_, count| -count }.first(5).map { |category, count| "- #{category || 'Uncategorized'}: #{count} tickets" }.join("\n")}
"""

    analysis
  end

  def analyze_resolution_times(tickets_query)
    tickets = tickets_query.to_a.select { |t| ['resolved', 'closed'].include?(t.status) && t.resolved_at.present? }
    
    return 'No resolved tickets found for resolution time analysis.' if tickets.empty?

    resolution_times = tickets.map { |t| (t.resolved_at - t.created_at) / 1.hour }
    avg_time = (resolution_times.sum / resolution_times.count).round(2)
    median_time = resolution_times.sort[resolution_times.count / 2].round(2)
    min_time = resolution_times.min.round(2)
    max_time = resolution_times.max.round(2)

    # Group by time ranges
    quick_resolutions = resolution_times.count { |t| t <= 4 }  # <= 4 hours
    same_day = resolution_times.count { |t| t <= 24 }  # <= 24 hours
    within_week = resolution_times.count { |t| t <= 168 }  # <= 1 week

    analysis = """
⏱️ **Resolution Time Analysis**

**Time Statistics:**
- Average Resolution Time: #{avg_time} hours
- Median Resolution Time: #{median_time} hours
- Fastest Resolution: #{min_time} hours
- Slowest Resolution: #{max_time} hours

**Resolution Speed Distribution:**
- Quick (≤4 hours): #{quick_resolutions} tickets (#{(quick_resolutions.to_f / tickets.count * 100).round(1)}%)
- Same Day (≤24 hours): #{same_day} tickets (#{(same_day.to_f / tickets.count * 100).round(1)}%)
- Within Week (≤168 hours): #{within_week} tickets (#{(within_week.to_f / tickets.count * 100).round(1)}%)

**Performance Insights:**
#{generate_resolution_insights(avg_time, quick_resolutions, tickets.count)}
"""

    analysis
  end

  def analyze_escalations(tickets_query)
    tickets = tickets_query.to_a
    total_count = tickets.count
    
    return 'No tickets found for escalation analysis.' if total_count.zero?

    escalated_tickets = tickets.select { |t| t.jira_issue_key.present? }
    escalated_count = escalated_tickets.count
    escalation_rate = (escalated_count.to_f / total_count * 100).round(1)

    # Analyze escalation by priority
    escalation_by_priority = tickets.group_by(&:priority).transform_values do |priority_tickets|
      escalated_in_priority = priority_tickets.count { |t| t.jira_issue_key.present? }
      {
        total: priority_tickets.count,
        escalated: escalated_in_priority,
        rate: priority_tickets.count > 0 ? (escalated_in_priority.to_f / priority_tickets.count * 100).round(1) : 0
      }
    end

    analysis = """
🚨 **Escalation Analysis**

**Overall Escalation Metrics:**
- Total Escalated: #{escalated_count} / #{total_count} tickets (#{escalation_rate}%)
- Non-escalated: #{total_count - escalated_count} tickets

**Escalation by Priority:**
#{escalation_by_priority.map do |priority, data|
  "- #{priority&.humanize || 'No Priority'}: #{data[:escalated]}/#{data[:total]} (#{data[:rate]}%)"
end.join("\n")}

**Escalation Insights:**
#{generate_escalation_insights(escalation_rate, escalation_by_priority)}
"""

    analysis
  end

  def analyze_feature_requests(tickets_query)
    # Modify query to include all tickets for comparison
    all_tickets = tickets_query.unscope(:where).where(
      created_at: tickets_query.where_values_hash['created_at'] || (30.days.ago..Time.current)
    ).to_a
    
    feature_requests = all_tickets.select(&:is_feature_request?)
    regular_tickets = all_tickets.reject(&:is_feature_request?)
    
    total_count = all_tickets.count
    fr_count = feature_requests.count
    regular_count = regular_tickets.count

    return 'No tickets found for feature request analysis.' if total_count.zero?

    # Analyze feature request trends
    fr_by_status = feature_requests.group_by(&:status).transform_values(&:count)
    fr_by_priority = feature_requests.group_by(&:priority).transform_values(&:count)
    fr_by_category = feature_requests.group_by(&:category).transform_values(&:count)

    analysis = """
💡 **Feature Requests Analysis**

**Overview:**
- Total Tickets: #{total_count}
- Feature Requests: #{fr_count} (#{(fr_count.to_f / total_count * 100).round(1)}%)
- Regular Tickets: #{regular_count} (#{(regular_count.to_f / total_count * 100).round(1)}%)

**Feature Request Status:**
#{fr_by_status.map { |status, count| "- #{status.humanize}: #{count}" }.join("\n")}

**Feature Request Priority:**
#{fr_by_priority.map { |priority, count| "- #{priority&.humanize || 'No Priority'}: #{count}" }.join("\n")}

**Feature Request Categories:**
#{fr_by_category.sort_by { |_, count| -count }.first(5).map { |category, count| "- #{category || 'Uncategorized'}: #{count}" }.join("\n")}

**Insights:**
#{generate_feature_request_insights(feature_requests, regular_tickets)}
"""

    analysis
  end

  def analyze_agent_performance(tickets_query)
    tickets = tickets_query.includes(:assigned_agent).to_a
    total_count = tickets.count
    
    return 'No tickets found for agent performance analysis.' if total_count.zero?

    # Group by assigned agent
    agent_stats = tickets.group_by(&:assigned_agent).transform_values do |agent_tickets|
      resolved_tickets = agent_tickets.select { |t| ['resolved', 'closed'].include?(t.status) && t.resolved_at.present? }
      avg_resolution = if resolved_tickets.any?
        total_time = resolved_tickets.sum { |t| (t.resolved_at - t.created_at) / 1.hour }
        (total_time / resolved_tickets.count).round(2)
      else
        0
      end

      {
        total: agent_tickets.count,
        resolved: resolved_tickets.count,
        resolution_rate: agent_tickets.count > 0 ? (resolved_tickets.count.to_f / agent_tickets.count * 100).round(1) : 0,
        avg_resolution_time: avg_resolution,
        escalated: agent_tickets.count { |t| t.jira_issue_key.present? }
      }
    end

    analysis = """
👥 **Agent Performance Analysis**

**Performance Overview:**
#{agent_stats.map do |agent, stats|
  agent_name = agent&.name || 'Unassigned'
  """- **#{agent_name}:**
  - Assigned: #{stats[:total]} tickets
  - Resolved: #{stats[:resolved]} tickets (#{stats[:resolution_rate]}%)
  - Avg Resolution Time: #{stats[:avg_resolution_time]} hours
  - Escalated: #{stats[:escalated]} tickets"""
end.join("\n\n")}

**Top Performers (by resolution rate):**
#{agent_stats.sort_by { |_, stats| -stats[:resolution_rate] }.first(3).map do |agent, stats|
  "- #{agent&.name || 'Unassigned'}: #{stats[:resolution_rate]}% resolution rate"
end.join("\n")}
"""

    analysis
  end

  def generate_custom_analysis(tickets_query, arguments)
    tickets = tickets_query.to_a
    
    # Generate a comprehensive custom analysis
    analysis = """
🔍 **Custom Ticket Analysis**

**Dataset Overview:**
- Total Tickets Analyzed: #{tickets.count}
- Date Range: #{arguments.dig('date_range', 'from') || '30 days ago'} to #{arguments.dig('date_range', 'to') || 'today'}
- Applied Filters: #{format_applied_filters(arguments['filters'] || {})}

**Quick Insights:**
#{generate_quick_insights(tickets)}

**Detailed Breakdown:**
#{generate_detailed_breakdown(tickets)}
"""

    analysis
  end

  def generate_comprehensive_insights(tickets, status_counts, priority_counts, escalation_rate, avg_resolution_time, recent_tickets, recent_high_priority)
    insights = []
    
    total_count = tickets.count
    resolved_count = (status_counts['resolved'] || 0) + (status_counts['closed'] || 0)
    open_count = (status_counts['open'] || 0) + (status_counts['in_progress'] || 0)
    
    # Resolution rate insights
    resolution_rate = (resolved_count.to_f / total_count * 100).round(1)
    if resolution_rate > 80
      insights << "✅ Excellent resolution rate (#{resolution_rate}%) indicates strong ticket management"
    elsif resolution_rate < 50
      insights << "⚠️ Low resolution rate (#{resolution_rate}%) - #{open_count} tickets need attention"
    else
      insights << "📊 Moderate resolution rate (#{resolution_rate}%) - room for improvement"
    end
    
    # Escalation insights
    if escalation_rate > 30
      insights << "🚨 High escalation rate (#{escalation_rate}%) suggests complex issues requiring review"
    elsif escalation_rate < 10
      insights << "✅ Low escalation rate (#{escalation_rate}%) indicates effective first-line support"
    else
      insights << "📈 Moderate escalation rate (#{escalation_rate}%) - standard patterns"
    end
    
    # Resolution time insights
    if avg_resolution_time > 0
      if avg_resolution_time < 24
        insights << "⚡ Fast average resolution time (#{avg_resolution_time}h) - excellent support efficiency"
      elsif avg_resolution_time > 72
        insights << "🐌 Slow average resolution time (#{avg_resolution_time}h) - process optimization needed"
      else
        insights << "⏱️ Moderate resolution time (#{avg_resolution_time}h) - acceptable performance"
      end
    end
    
    # Priority insights
    high_priority_count = (priority_counts['urgent'] || 0) + (priority_counts['high'] || 0)
    high_priority_rate = (high_priority_count.to_f / total_count * 100).round(1)
    if high_priority_rate > 40
      insights << "🔴 High percentage of urgent/high priority tickets (#{high_priority_rate}%) - review issue complexity"
    elsif high_priority_rate < 20
      insights << "🟢 Low percentage of high priority tickets (#{high_priority_rate}%) - good issue management"
    end
    
    # Recent activity insights
    if recent_tickets.count > 10
      insights << "🚀 High recent activity (#{recent_tickets.count} tickets in 24h) - increased support demand"
    end
    
    if recent_high_priority.count > 3
      insights << "⚠️ Multiple high priority issues in last 24h (#{recent_high_priority.count}) - immediate attention needed"
    end
    
    # Feature request insights
    fr_count = tickets.count(&:is_feature_request?)
    if fr_count > total_count * 0.3
      insights << "💡 High volume of feature requests (#{fr_count}) indicates active user engagement"
    end
    
    insights.empty? ? "📊 Standard ticket patterns observed across all metrics." : insights.join("\n")
  end

  def generate_insights(tickets, status_counts, priority_counts, escalation_rate, avg_resolution_time)
    insights = []
    
    total_count = tickets.count
    resolved_count = (status_counts['resolved'] || 0) + (status_counts['closed'] || 0)
    open_count = (status_counts['open'] || 0) + (status_counts['in_progress'] || 0)
    
    if resolved_count.to_f / total_count > 0.8
      insights << "✅ High resolution rate (#{(resolved_count.to_f / total_count * 100).round(1)}%) indicates good ticket management"
    elsif resolved_count.to_f / total_count < 0.5
      insights << "⚠️ Low resolution rate (#{(resolved_count.to_f / total_count * 100).round(1)}%) - consider reviewing open tickets"
    end
    
    if escalation_rate > 30
      insights << "🚨 High escalation rate (#{escalation_rate}%) - may indicate complex issues requiring attention"
    elsif escalation_rate < 10
      insights << "✅ Low escalation rate (#{escalation_rate}%) suggests efficient issue resolution"
    end
    
    if avg_resolution_time < 24
      insights << "⚡ Fast average resolution time (#{avg_resolution_time} hours) indicates efficient support"
    elsif avg_resolution_time > 72
      insights << "🐌 Slow average resolution time (#{avg_resolution_time} hours) - consider process optimization"
    end
    
    high_priority_count = (priority_counts['urgent'] || 0) + (priority_counts['high'] || 0)
    if high_priority_count.to_f / total_count > 0.3
      insights << "🔴 High percentage of urgent/high priority tickets (#{(high_priority_count.to_f / total_count * 100).round(1)}%)"
    end
    
    insights.empty? ? "No specific insights identified for this dataset." : insights.join("\n")
  end

  def generate_resolution_insights(avg_time, quick_count, total_count)
    insights = []
    
    quick_percentage = (quick_count.to_f / total_count * 100).round(1)
    
    if avg_time < 12
      insights << "✅ Excellent average resolution time"
    elsif avg_time > 48
      insights << "⚠️ Consider reviewing processes to improve resolution speed"
    end
    
    if quick_percentage > 50
      insights << "🚀 More than half of tickets resolved within 4 hours"
    elsif quick_percentage < 20
      insights << "📈 Opportunity to improve quick resolution rate"
    end
    
    insights.join("\n")
  end

  def generate_escalation_insights(escalation_rate, escalation_by_priority)
    insights = []
    
    if escalation_rate > 25
      insights << "🚨 High escalation rate indicates complex issues"
    elsif escalation_rate < 5
      insights << "✅ Low escalation rate suggests effective first-line support"
    end
    
    urgent_escalation = escalation_by_priority['urgent']
    if urgent_escalation && urgent_escalation[:rate] > 50
      insights << "⚠️ High escalation rate for urgent tickets - review urgent ticket handling"
    end
    
    insights.empty? ? "Standard escalation patterns observed." : insights.join("\n")
  end

  def generate_feature_request_insights(feature_requests, regular_tickets)
    insights = []
    
    if feature_requests.any?
      resolved_fr = feature_requests.count { |t| ['resolved', 'closed'].include?(t.status) }
      fr_resolution_rate = (resolved_fr.to_f / feature_requests.count * 100).round(1)
      
      insights << "📈 Feature request resolution rate: #{fr_resolution_rate}%"
      
      if feature_requests.count > regular_tickets.count * 0.2
        insights << "💡 High volume of feature requests indicates active user engagement"
      end
    else
      insights << "ℹ️ No feature requests in current dataset"
    end
    
    insights.join("\n")
  end

  def generate_quick_insights(tickets)
    return "No tickets to analyze." if tickets.empty?

    status_dist = tickets.group_by(&:status).transform_values(&:count)
    most_common_status = status_dist.max_by { |_, count| count }&.first
    
    priority_dist = tickets.group_by(&:priority).transform_values(&:count)
    escalated_count = tickets.count { |t| t.jira_issue_key.present? }
    
    """
- Most common status: #{most_common_status&.humanize}
- Priority distribution: #{priority_dist.map { |p, c| "#{p&.humanize || 'None'}: #{c}" }.join(', ')}
- Escalation rate: #{(escalated_count.to_f / tickets.count * 100).round(1)}%
- Feature requests: #{tickets.count(&:is_feature_request?)} (#{(tickets.count(&:is_feature_request?).to_f / tickets.count * 100).round(1)}%)
"""
  end

  def generate_detailed_breakdown(tickets)
    categories = tickets.group_by(&:category).transform_values(&:count)
    agents = tickets.group_by(&:assigned_agent).transform_values(&:count)
    
    """
**By Category:**
#{categories.sort_by { |_, count| -count }.first(5).map { |cat, count| "- #{cat || 'Uncategorized'}: #{count}" }.join("\n")}

**By Agent:**
#{agents.sort_by { |_, count| -count }.first(5).map { |agent, count| "- #{agent&.name || 'Unassigned'}: #{count}" }.join("\n")}
"""
  end

  def format_applied_filters(filters)
    return "None" if filters.empty?
    
    filters.map { |key, value| "#{key}: #{value}" }.join(", ")
  end

  def generate_date_context(date_range = {})
    current_date = Date.current
    current_time = Time.current.strftime('%I:%M %p %Z')
    
    context = "📅 **Analysis Context:** Generated on #{current_date.strftime('%A, %B %d, %Y')} at #{current_time}\n"
    
    if date_range['from'].present? || date_range['to'].present?
      from_date = date_range['from'] ? Date.parse(date_range['from']) : nil
      to_date = date_range['to'] ? Date.parse(date_range['to']) : nil
      
      if from_date && to_date
        context += "📊 **Date Range:** #{from_date.strftime('%B %d, %Y')} to #{to_date.strftime('%B %d, %Y')}\n"
      elsif from_date
        context += "📊 **Date Range:** From #{from_date.strftime('%B %d, %Y')} onwards\n"
      elsif to_date
        context += "📊 **Date Range:** Up to #{to_date.strftime('%B %d, %Y')}\n"
      end
      
      # Add relative time context
      if from_date == current_date
        context += "🕐 **Time Context:** Today's data\n"
      elsif from_date == current_date.beginning_of_week
        context += "🕐 **Time Context:** This week's data\n"
      elsif from_date == current_date.beginning_of_month
        context += "🕐 **Time Context:** This month's data\n"
      end
    else
      context += "📊 **Date Range:** All historical data (no date filter applied)\n"
    end
    
    context + "\n"
  end
end
