class Integrations::Plane::ProcessorService
  pattr_initialize [:account!]

  def projects
    response = plane_client.projects
    
    # Handle error response
    if response.is_a?(Hash) && (response[:error] || response['error'])
      return { error: response[:error] || response['error'] }
    end
    
    # Handle successful response (array of projects)
    if response.is_a?(Array)
      { data: response }
    else
      { error: 'Unexpected response format from Plane' }
    end
  end

  def project_metadata(project_id)
    response = plane_client.project_metadata(project_id)
    
    # Handle error responses
    if response.is_a?(Hash) && (response[:error] || response['error'])
      return response
    end

    {
      data: {
        project: response['project'],
        states: response['states'] || [],
        labels: response['labels'] || [],
        members: response['members'] || [],
        priorities: response['priorities'] || default_priorities
      }
    }
  end

  def create_issue(params)
    # Get project identifier for the issue key
    project_identifier = get_project_identifier(params[:project_id])
    
    enhanced_params = params.merge(project_identifier: project_identifier)
    response = plane_client.create_issue(enhanced_params)
    
    # Handle error responses
    if response.is_a?(Hash) && (response[:error] || response['error'])
      return response
    end

    {
      data: {
        id: response['id'],
        key: response['identifier'] || "#{project_identifier}-#{response['sequence_id']}",
        sequence_id: response['sequence_id'],
        project_id: params[:project_id],
        title: response['name'],
        url: issue_url(params[:project_id], response['id'])
      }
    }
  end

  def link_issue(conversation_data, project_id, issue_id, title, user: nil)
    begin
      issue_key = get_issue_key(project_id, issue_id)
      
      # Add a link in Plane pointing to the conversation
      link_response = plane_client.link_issue(project_id, issue_id, conversation_data[:url], title)
      link_id = link_response.is_a?(Hash) && !link_response[:error] ? link_response['id'] : nil
      
      # Fetch current issue state for initial tracking
      current_state = nil
      current_state_name = nil
      begin
        issue_response = plane_client.get_issue(project_id, issue_id)
        if issue_response && !issue_response[:error]
          current_state = issue_response['state']
          current_state_name = issue_response.dig('state_detail', 'name') || determine_state_name(project_id, current_state)
        end
      rescue StandardError => e
        Rails.logger.warn("Plane: Could not fetch initial state for issue #{issue_id}: #{e.message}")
      end
      
      # Store the link in our database
      link = PlaneIssueLink.link_issue(
        conversation_data[:conversation], 
        project_id,
        issue_id,
        issue_key,
        link_id: link_id,
        user: user
      )
      
      # Update the initial state if we got it
      if current_state_name
        link.update_state!(current_state_name)
        Rails.logger.info("Plane: Set initial state for issue #{issue_key}: #{current_state_name}")
      end

      {
        data: {
          issue_id: issue_id,
          issue_key: issue_key,
          project_id: project_id,
          url: conversation_data[:url],
          link_id: link_id,
          linked_at: link.linked_at,
          initial_state: current_state_name
        }
      }
    rescue StandardError => e
      Rails.logger.error("Plane link_issue error: #{e.message}")
      { error: e.message }
    end
  end

  def unlink_issue(conversation_id, project_id, issue_id)
    begin
      issue_key = get_issue_key(project_id, issue_id)
      
      # Check if this issue is linked to any tickets
      tickets_with_issue = Ticket.where(plane_issue_id: issue_id)
      
      if tickets_with_issue.exists?
        raise StandardError, "Cannot unlink Plane issue #{issue_key} as it is linked to #{tickets_with_issue.count} ticket(s). Please remove the Plane link from the ticket(s) first."
      end
      
      # Remove from our database
      PlaneIssueLink.unlink_issue(conversation_id, issue_id)
      
      { data: { success: true, issue_id: issue_id, issue_key: issue_key } }
    rescue StandardError => e
      Rails.logger.error("Plane unlink_issue error: #{e.message}")
      { error: e.message }
    end
  end

  def search_issues(query, project_id = nil)
    response = plane_client.search_issues(query, project_id)

    # Handle error responses
    if response.is_a?(Hash) && (response[:error] || response['error'])
      return response
    end

    # Handle successful response (array of issues)
    issues_array = response.is_a?(Array) ? response : []
    issues = issues_array.map do |issue|
      project = issue['project_id'] || project_id
      state_detail = issue['state_detail']
      state_data = issue['state']

      # Handle state as Hash object (expanded) or UUID string
      if state_data.is_a?(Hash)
        state_name = state_data['name'] || 'Unknown'
      elsif state_detail.is_a?(Hash)
        state_name = state_detail['name'] || 'Unknown'
      else
        state_name = determine_state_name(project, state_data) rescue 'Unknown'
      end

      issue_key = "#{get_project_identifier(project)}-#{issue['sequence_id']}"
      {
        id: issue['id'],
        key: issue_key,
        sequence_id: issue_key,
        project_id: project,
        name: issue['name'],
        summary: issue['name'],
        state_name: state_name,
        status: state_name,
        assignees: issue['assignee_details']&.map { |a| a['display_name'] },
        priority: issue['priority'],
        url: issue_url(project, issue['id'])
      }
    end

    { data: issues }
  end

  def linked_issues(conversation_id)
    begin
      # Get linked issues from database
      links = PlaneIssueLink.where(conversation_id: conversation_id)
      
      if links.empty?
        return { data: [] }
      end
      
      # Fetch issue details from Plane for each linked issue
      issues = []
      links.each do |link|
        begin
          issue_response = plane_client.get_issue(link.project_id, link.issue_id)
          
          # If there's an error fetching this issue, fall back to local data
          if issue_response.is_a?(Hash) && (issue_response[:error] || issue_response['error'])
            Rails.logger.warn("Plane: Could not fetch details for linked issue #{link.issue_key}: #{issue_response[:error] || issue_response['error']}. Falling back to local data.")
            issues << {
              id: link.issue_id,
              key: link.issue_key,
              name: link.issue_key,
              summary: link.issue_key,
              state_name: link.last_known_state || 'Unknown',
              state_color: '#94a3b8',
              assignees: [],
              priority: nil,
              url: issue_url(link.project_id, link.issue_id),
              link_id: link.link_id,
              linked_at: link.linked_at&.iso8601,
              project_id: link.project_id,
              workspace_slug: plane_workspace_slug
            }
            next
          end

          # Extract state info — handle both object and UUID formats
          state_data = issue_response['state']
          if state_data.is_a?(Hash)
            state_name = state_data['name'] || link.last_known_state || 'Unknown'
            state_color = state_data['color'] || determine_state_color(link.project_id, state_data['id'])
          else
            state_name = issue_response.dig('state_detail', 'name') || determine_state_name(link.project_id, state_data)
            state_color = issue_response.dig('state_detail', 'color') || determine_state_color(link.project_id, state_data)
          end

          issues << {
            id: issue_response['id'],
            key: link.issue_key,
            sequence_id: issue_response['sequence_id'],
            name: issue_response['name'],
            summary: issue_response['name'],
            state_name: state_name,
            state_color: state_color,
            assignees: issue_response['assignee_details']&.map { |a| { 'display_name' => a['display_name'] } },
            priority: issue_response['priority'],
            url: issue_url(link.project_id, link.issue_id),
            link_id: link.link_id,
            linked_at: link.linked_at&.iso8601,
            project_id: link.project_id,
            workspace_slug: plane_workspace_slug
          }
        rescue StandardError => e
          Rails.logger.warn("Plane: Error fetching issue #{link.issue_key}: #{e.message}. Falling back to local data.")
          issues << {
            id: link.issue_id,
            key: link.issue_key,
            name: link.issue_key,
            summary: link.issue_key,
            state_name: link.last_known_state || 'Unknown',
            state_color: '#94a3b8',
            assignees: [],
            priority: nil,
            url: issue_url(link.project_id, link.issue_id),
            link_id: link.link_id,
            linked_at: link.linked_at&.iso8601,
            project_id: link.project_id,
            workspace_slug: plane_workspace_slug
          }
        end
      end
      
      # Sort by linked_at date (most recent first)
      issues.sort! { |a, b| (b[:linked_at] || '') <=> (a[:linked_at] || '') }

      { data: issues }
    rescue StandardError => e
      Rails.logger.error("Plane linked_issues error: #{e.message}")
      { error: e.message }
    end
  end

  def get_issue(project_id, issue_id)
    response = plane_client.get_issue(project_id, issue_id)
    
    # Handle error responses
    if response.is_a?(Hash) && (response[:error] || response['error'])
      return response
    end

    issue = response
    {
      data: {
        id: issue['id'],
        key: "#{get_project_identifier(project_id)}-#{issue['sequence_id']}",
        summary: issue['name'],
        description: extract_description(issue['description_html']),
        status: issue.dig('state_detail', 'name') || determine_state_name(project_id, issue['state']),
        assignees: issue['assignee_details']&.map { |a| a['display_name'] },
        priority: issue['priority'],
        labels: issue['label_details']&.map { |l| l['name'] } || [],
        created_at: issue['created_at'],
        updated_at: issue['updated_at'],
        target_date: issue['target_date'],
        url: issue_url(project_id, issue['id'])
      }
    }
  end

  def get_comments(project_id, issue_id)
    response = plane_client.get_comments(project_id, issue_id)
    
    # Handle error responses
    if response.is_a?(Hash) && (response[:error] || response['error'])
      return response
    end

    # Handle successful response (array of comments)
    if response.is_a?(Array)
      { data: response }
    else
      { error: 'Unexpected response format from Plane' }
    end
  end

  def add_comment(project_id, issue_id, comment_body)
    response = plane_client.add_comment(project_id, issue_id, comment_body)
    
    # Handle error responses
    if response.is_a?(Hash) && (response[:error] || response['error'])
      return response
    end

    { data: response }
  end

  def add_attachment(project_id, issue_id, file_path, filename = nil)
    response = plane_client.add_attachment(project_id, issue_id, file_path, filename)
    
    # Handle error responses
    if response.is_a?(Hash) && (response[:error] || response['error'])
      return response
    end

    { data: response }
  end

  def update_issue_labels(project_id, issue_id, label_ids)
    response = plane_client.update_issue_labels(project_id, issue_id, label_ids)
    
    # Handle error responses
    if response.is_a?(Hash) && (response[:error] || response['error'])
      return response
    end

    { data: { success: true, labels: label_ids } }
  end

  def update_issue_state(project_id, issue_id, state_id)
    response = plane_client.update_issue_state(project_id, issue_id, state_id)
    
    # Handle error responses
    if response.is_a?(Hash) && (response[:error] || response['error'])
      return response
    end

    { data: response }
  end

  def update_issue(project_id, issue_id, params)
    response = plane_client.update_issue(project_id, issue_id, params)
    
    # Handle error responses
    if response.is_a?(Hash) && (response[:error] || response['error'])
      return response
    end

    { data: response }
  end

  private

  def plane_hook
    @plane_hook ||= account.hooks.find_by!(app_id: 'plane')
  end

  def plane_client
    @plane_client ||= begin
      hook_settings = plane_hook.settings
      auth_config = {
        base_url: hook_settings['api_url'] || hook_settings['base_url'],
        api_key: hook_settings['api_key'],
        workspace_slug: hook_settings['workspace_slug']
      }
      
      Plane.new(auth_config)
    end
  end

  def plane_base_url
    @plane_base_url ||= plane_hook.settings['api_url'] || plane_hook.settings['base_url']
  end

  def plane_web_url
    @plane_web_url ||= plane_hook.settings['web_url'].presence || plane_base_url
  end

  def plane_workspace_slug
    @plane_workspace_slug ||= plane_hook.settings['workspace_slug']
  end

  def issue_url(project_id, issue_id)
    "#{plane_web_url}/#{plane_workspace_slug}/projects/#{project_id}/issues/#{issue_id}"
  end

  def get_project_identifier(project_id)
    @project_identifiers ||= {}
    @project_identifiers[project_id] ||= begin
      project = plane_client.get_project(project_id)
      project.is_a?(Hash) && !project[:error] ? project['identifier'] : 'PROJ'
    end
  end

  def get_issue_key(project_id, issue_id)
    # Try to get from existing link first
    link = PlaneIssueLink.find_by(project_id: project_id, issue_id: issue_id)
    return link.issue_key if link&.issue_key.present?
    
    # Otherwise fetch from Plane
    issue = plane_client.get_issue(project_id, issue_id)
    return "UNKNOWN-#{issue_id}" if issue.is_a?(Hash) && issue[:error]
    
    "#{get_project_identifier(project_id)}-#{issue['sequence_id']}"
  end

  def determine_state_name(project_id, state_id)
    return 'Unknown' if state_id.blank?

    # Handle Hash state objects (Plane sends state as object in webhooks)
    return state_id['name'] || 'Unknown' if state_id.is_a?(Hash)

    states = plane_client.get_project_states(project_id)
    return 'Unknown' if states.is_a?(Hash) && states[:error]
    
    state = states.find { |s| s['id'] == state_id }
    state&.dig('name') || 'Unknown'
  end

  def determine_state_color(project_id, state_id)
    return '#94a3b8' if state_id.blank?

    # Handle Hash state objects (Plane sends state as object in webhooks)
    if state_id.is_a?(Hash)
      hook = @account&.hooks&.find_by(app_id: 'plane')
      custom_colors = hook&.settings&.dig('status_colors') || {}
      return custom_colors[state_id['name']] || state_id['color'] || '#94a3b8'
    end

    # Check account hook settings for custom colors first
    hook = @account&.hooks&.find_by(app_id: 'plane')
    custom_colors = hook&.settings&.dig('status_colors') || {}

    states = plane_client.get_project_states(project_id)
    return '#94a3b8' if states.is_a?(Hash) && states[:error]

    state = states.find { |s| s['id'] == state_id }
    return '#94a3b8' unless state

    # Prefer custom color from settings, then Plane's own color
    custom_colors[state['name']] || state['color'] || '#94a3b8'
  end

  def extract_description(description_html)
    return '' unless description_html
    
    # Simple HTML stripping - in production you might want ActionView::Base.full_sanitizer
    description_html.gsub(/<[^>]*>/, ' ').gsub(/\s+/, ' ').strip
  end

  def default_priorities
    [
      { id: 'urgent', name: 'Urgent' },
      { id: 'high', name: 'High' },
      { id: 'medium', name: 'Medium' },
      { id: 'low', name: 'Low' },
      { id: 'none', name: 'None' }
    ]
  end
end
