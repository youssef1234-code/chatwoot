class Integrations::Jira::ProcessorService
  pattr_initialize [:account!]

  def projects
    response = jira_client.projects
    
    # Handle error response (hash with :error key)
    if response.is_a?(Hash) && (response[:error] || response['error'])
      return { error: response[:error] || response['error'] }
    end
    
    # Handle successful response (array of projects)
    if response.is_a?(Array)
      { data: response }
    else
      { error: 'Unexpected response format from JIRA' }
    end
  end

  def statuses
    response = jira_client.statuses

    if response.is_a?(Hash) && (response[:error] || response['error'])
      return { error: response[:error] || response['error'] }
    end

    if response.is_a?(Array)
      { data: response }
    else
      { error: 'Unexpected response format from JIRA' }
    end
  end

  def project_metadata(project_key)
    response = jira_client.project_metadata(project_key)
    
    # Handle error responses (can have string or symbol keys)
    if response.is_a?(Hash) && (response[:error] || response['error'])
      return response
    end

    {
      data: {
        project: response['project'],
        issue_types: response['issue_types'] || [],
        users: response['users'] || [],
        priorities: response['priorities'] || default_priorities
      }
    }
  end

  def create_issue(params)
    response = jira_client.create_issue(params)
    
    # Handle error responses (can have string or symbol keys)
    if response.is_a?(Hash) && (response[:error] || response['error'])
      return response
    end

    {
      data: {
        id: response['key'],
        key: response['key'],
        title: params[:summary],
        url: "#{jira_site_url}/browse/#{response['key']}"
      }
    }
  end

  def link_issue(conversation_data, issue_key, title, user: nil, message_ids: [])
    begin
      # Add a comment to JIRA (optional - for reference)
      comment_response = jira_client.link_issue(issue_key, conversation_data[:url], title)
      comment_id = comment_response.is_a?(Hash) && !comment_response[:error] ? comment_response['id'] : nil
      
      # Fetch current issue status for initial tracking
      current_status = nil
      begin
        issue_response = jira_client.get_issue(issue_key)
        current_status = issue_response['fields']['status']['name'] if issue_response && !issue_response[:error]
      rescue StandardError => e
        Rails.logger.warn("JIRA: Could not fetch initial status for issue #{issue_key}: #{e.message}")
      end
      
      # Store the link in our database
      link = JiraIssueLink.link_issue(
        conversation_data[:conversation], 
        issue_key, 
        comment_id: comment_id,
        user: user,
        message_ids: message_ids
      )
      
      # Update the initial status if we got it
      if current_status
        link.update_status!(current_status)
        Rails.logger.info("JIRA: Set initial status for issue #{issue_key}: #{current_status}")
      end

      {
        data: {
          issue_key: issue_key,
          url: conversation_data[:url],
          comment_id: comment_id,
          linked_at: link.linked_at,
          initial_status: current_status
        }
      }
    rescue StandardError => e
      Rails.logger.error("JIRA link_issue error: #{e.message}")
      { error: e.message }
    end
  end

  def unlink_issue(conversation_id, issue_key, _comment_id = nil)
    begin
      # Simply remove from our database - don't touch JIRA
      JiraIssueLink.unlink_issue(conversation_id, issue_key)
      
      { data: { success: true, issue_key: issue_key } }
    rescue StandardError => e
      Rails.logger.error("JIRA unlink_issue error: #{e.message}")
      { error: e.message }
    end
  end

  def search_issue(query)
    response = jira_client.search_issue(query)

    # Handle error responses (can have string or symbol keys)
    if response.is_a?(Hash) && (response[:error] || response['error'])
      return response
    end

    # Handle successful response (array of issues)
    issues_array = response.is_a?(Array) ? response : []
    issues = issues_array.map do |issue|
      {
        key: issue['key'],
        summary: issue['summary'],
        status: issue['status'],
        assignee: issue['assignee'],
        priority: issue['priority'],
        issueType: issue['issueType'],
        url: issue['url']
      }
    end

    { data: issues }
  end

  def linked_issues(conversation_id)
    begin
      # Get linked issues from database
      linked_issue_keys = JiraIssueLink.linked_issues_for_conversation(conversation_id)
      
      if linked_issue_keys.empty?
        return { data: [] }
      end
      
      # Fetch issue details from JIRA for each linked issue
      issues = []
      linked_issue_keys.each do |issue_key|
        begin
          issue_response = jira_client.get_issue(issue_key)
          
          # Skip if there's an error fetching this specific issue
          if issue_response.is_a?(Hash) && (issue_response[:error] || issue_response['error'])
            Rails.logger.warn("JIRA: Could not fetch details for linked issue #{issue_key}: #{issue_response[:error] || issue_response['error']}")
            next
          end
          
          # Get the link record for additional metadata
          link_record = JiraIssueLink.find_by(conversation_id: conversation_id, issue_key: issue_key)
          
          issues << {
            key: issue_response['key'],
            summary: issue_response['fields']['summary'],
            status: issue_response['fields']['status']['name'],
            assignee: issue_response['fields']['assignee']&.dig('displayName'),
            priority: issue_response['fields']['priority']&.dig('name'),
            issueType: issue_response['fields']['issuetype']['name'],
            url: "#{jira_site_url}/browse/#{issue_response['key']}",
            id: issue_response['key'], # Use key as ID for frontend compatibility
            commentId: link_record&.comment_id, # Use comment ID from database
            linked_at: link_record&.linked_at&.iso8601, # Include the link date for sorting
            message_ids: link_record&.message_ids || [],
            escalated_to: link_record&.escalated_to,
            escalated_from: link_record&.escalated_from
          }
        rescue StandardError => e
          Rails.logger.warn("JIRA: Error fetching issue #{issue_key}: #{e.message}")
          # Continue with other issues even if one fails
          next
        end
      end
      
      # Sort by linked_at date (most recent first)
      issues.sort! { |a, b| (b[:linked_at] || '') <=> (a[:linked_at] || '') }

      { data: issues, second_line_project_key: jira_hook.settings['second_line_project_key'] }
    rescue StandardError => e
      Rails.logger.error("JIRA linked_issues error: #{e.message}")
      { error: e.message }
    end
  end

  def get_issue(issue_key)
    response = jira_client.get_issue(issue_key)
    
    # Handle error responses (can have string or symbol keys)
    if response.is_a?(Hash) && (response[:error] || response['error'])
      return response
    end

    issue = response
    {
      data: {
        key: issue['key'],
        summary: issue['fields']['summary'],
        description: extract_description(issue['fields']['description']),
        status: issue['fields']['status']['name'],
        assignee: issue['fields']['assignee']&.dig('displayName'),
        priority: issue['fields']['priority']&.dig('name'),
        issueType: issue['fields']['issuetype']['name'],
        created: issue['fields']['created'],
        updated: issue['fields']['updated'],
        labels: issue['fields']['labels'] || [],
        url: "#{jira_site_url}/browse/#{issue['key']}"
      }
    }
  end

  def get_comments(issue_key)
    response = jira_client.get_comments(issue_key)
    
    # Handle error responses (can have string or symbol keys)
    if response.is_a?(Hash) && (response[:error] || response['error'])
      return response
    end

    # Handle successful response (array of comments)
    if response.is_a?(Array)
      { data: response }
    else
      { error: 'Unexpected response format from JIRA' }
    end
  end

  def add_comment(issue_key, comment_body)
    response = jira_client.add_comment(issue_key, comment_body)
    
    # Handle error responses (can have string or symbol keys)
    if response.is_a?(Hash) && (response[:error] || response['error'])
      return response
    end

    { data: response }
  end

  def add_attachment(issue_key, file_path, filename = nil)
    response = jira_client.add_attachment(issue_key, file_path, filename)
    
    # Handle error responses (can have string or symbol keys)
    if response.is_a?(Hash) && (response[:error] || response['error'])
      return response
    end

    { data: response }
  end

  def update_issue_labels(issue_key, labels)
    response = jira_client.update_issue_labels(issue_key, labels)
    
    # Handle error responses (can have string or symbol keys)
    if response.is_a?(Hash) && (response[:error] || response['error'])
      return response
    end

    { data: { success: true, labels: labels } }
  end

  # Escalate a JIRA issue: create a new issue in the 2nd line project, linked to the original
  # reporter_email: the email of the user performing the escalation (they have a JIRA account)
  def escalate_issue(issue_key, target_project_key = nil, target_issue_type_id = nil, reporter_email: nil)
    # Use configured 2nd line project if not specified
    target_project_key ||= jira_hook.settings['second_line_project_key']
    return { error: 'No escalation project configured. Set the 2nd Line Project Key in JIRA integration settings.' } if target_project_key.blank?

    response = jira_client.escalate_to_second_line(
      issue_key, target_project_key, target_issue_type_id,
      reporter_email: reporter_email
    )

    if response.is_a?(Hash) && (response[:error] || response['error'])
      return response
    end

    { data: response }
  end

  # Update reporter on an existing issue
  def update_issue_reporter(issue_key, reporter_email)
    response = jira_client.update_issue_reporter(issue_key, reporter_email)

    if response.is_a?(Hash) && (response[:error] || response['error'])
      return response
    end

    { data: response }
  end

  # Find or create a JIRA Service Desk customer
  def find_or_create_customer(email, display_name)
    response = jira_client.find_or_create_customer(email, display_name)
    return { error: 'Failed to find or create customer' } if response.nil?

    { data: response }
  end

  # Add customer as participant to a Service Desk issue
  def add_customer_to_issue(issue_key, customer_identifier)
    response = jira_client.add_request_participant(issue_key, customer_identifier)
    return { error: 'Failed to add customer to issue' } if response.nil?

    { data: response }
  end

  # Find or create a JIRA Service Management organization by name
  def find_or_create_organization(name)
    org = jira_client.find_or_create_organization(name)
    return { error: "Failed to find or create organization '#{name}'" } if org.nil?

    { data: org }
  end

  # Add an organization to the service desk associated with a project
  def add_organization_to_project_service_desk(project_key, organization_id)
    service_desk_id = jira_client.get_service_desk_id(project_key)
    return { error: "No service desk found for project #{project_key}" } if service_desk_id.nil?

    result = jira_client.add_organization_to_service_desk(service_desk_id, organization_id)
    result ? { data: true } : { error: 'Failed to add organization to service desk' }
  end

  # Add an organization to a specific JIRA Service Desk issue/request
  def add_organization_to_issue(issue_key, organization_id)
    result = jira_client.add_organization_to_request(issue_key, organization_id)
    result ? { data: true } : { error: 'Failed to add organization to issue' }
  end

  # Remove an organization from a JIRA Service Desk issue/request
  def remove_organization_from_issue(issue_key, organization_id)
    result = jira_client.remove_organization_from_request(issue_key, organization_id)
    result ? { data: true } : { error: 'Failed to remove organization from issue' }
  end

  # Get configured final/completion statuses
  def final_statuses
    statuses = jira_hook.settings['final_statuses']
    if statuses.is_a?(String)
      statuses.split(',').map(&:strip).reject(&:blank?)
    elsif statuses.is_a?(Array)
      statuses.map(&:strip).reject(&:blank?)
    else
      %w[Done Resolved Closed Complete Completed Canceled Solved]
    end
  end

  # Check if a status is a final/completion status
  def completed_status?(status)
    return false if status.blank?

    final_statuses.any? { |fs| status.downcase.include?(fs.downcase) }
  end

  # Get configured 1st line project key
  def first_line_project_key
    jira_hook.settings['first_line_project_key']
  end

  # Get configured 2nd line project key
  def second_line_project_key
    jira_hook.settings['second_line_project_key']
  end

  # Check if service desk customer management is enabled
  def service_desk_enabled?
    jira_hook.settings['service_desk_enabled'] != false
  end

  # Get deployment type
  def deployment_type
    jira_hook.settings['deployment_type'] || 'data_center'
  end

  # Fetch onboarding status from ScriptRunner for a given org name
  def onboarding_status(org_name)
    jira_client.onboarding_status(org_name)
  end

  private

  def jira_hook
    @jira_hook ||= account.hooks.find_by!(app_id: 'jira')
  end

  def jira_client
    @jira_client ||= begin
      hook_settings = jira_hook.settings
      deployment_type = hook_settings['deployment_type'] || 'data_center'

      # Always derive auth type from deployment type for consistency:
      # - Cloud uses API token with Basic auth (email + token)
      # - Data Center uses Personal Access Token with Bearer auth
      auth_type = deployment_type == 'data_center' ? 'personal_access_token' : 'api_token'
      # Allow explicit override only for oauth
      auth_type = 'oauth' if hook_settings['auth_type'] == 'oauth'

      auth_config = {
        site_url: jira_site_url,
        auth_type: auth_type,
        deployment_type: deployment_type
      }
      
      case auth_config[:auth_type]
      when 'api_token'
        auth_config[:email] = hook_settings['email']
        auth_config[:api_token] = hook_settings['api_token']
      when 'personal_access_token'
        auth_config[:api_token] = hook_settings['api_token']
      when 'oauth'
        auth_config[:access_token] = jira_hook.access_token
      end
      
      Jira.new(auth_config)
    end
  end

  def jira_site_url
    @jira_site_url ||= jira_hook.settings['site_url']
  end

  def extract_issue_types(response)
    return [] if response[:error]

    # JIRA API returns issue types per status, we need to extract unique issue types
    issue_types = []
    response.each do |status_group|
      status_group['issueTypes']&.each do |issue_type|
        unless issue_types.any? { |it| it['id'] == issue_type['id'] }
          issue_types << issue_type
        end
      end
    end
    issue_types
  end

  def extract_users(response)
    return [] if response[:error]

    response.map do |user|
      {
        accountId: user['accountId'],
        displayName: user['displayName'],
        emailAddress: user['emailAddress']
      }
    end
  end

  def default_priorities
    [
      { id: '1', name: 'Highest' },
      { id: '2', name: 'High' },
      { id: '3', name: 'Medium' },
      { id: '4', name: 'Low' },
      { id: '5', name: 'Lowest' }
    ]
  end

  def extract_description(description_obj)
    return '' unless description_obj
    
    # Handle string descriptions (plain text)
    return description_obj if description_obj.is_a?(String)
    
    # Handle hash descriptions (Atlassian Document Format)
    return '' unless description_obj.is_a?(Hash) && description_obj.dig('content')

    # Extract plain text from Atlassian Document Format
    description_obj['content'].map do |content_block|
      next unless content_block['type'] == 'paragraph'

      content_block['content']&.map { |text_node| text_node['text'] }&.join(' ')
    end.compact.join("\n\n")
  end

  def conversation_url_for(conversation)
    "#{ENV.fetch('FRONTEND_URL', nil)}/app/accounts/#{conversation.account_id}/conversations/#{conversation.display_id}"
  end
end
