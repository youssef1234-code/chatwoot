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

  def link_issue(conversation_data, issue_key, title, user: nil)
    begin
      # Add a comment to JIRA (optional - for reference)
      comment_response = jira_client.link_issue(issue_key, conversation_data[:url], title)
      comment_id = comment_response.is_a?(Hash) && !comment_response[:error] ? comment_response['id'] : nil
      
      # Store the link in our database
      link = JiraIssueLink.link_issue(
        conversation_data[:conversation], 
        issue_key, 
        comment_id: comment_id,
        user: user
      )

      {
        data: {
          issue_key: issue_key,
          url: conversation_data[:url],
          comment_id: comment_id,
          linked_at: link.linked_at
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
      # Get linked issue keys from our database
      linked_issue_keys = JiraIssueLink.linked_issues_for_conversation(conversation_id)
      
      if linked_issue_keys.empty?
        return { data: [] }
      end

      # Fetch issue details from JIRA for each linked issue
      issues = []
      linked_issue_keys.each do |issue_key|
        begin
          issue_response = jira_client.get_issue(issue_key)
          next if issue_response.is_a?(Hash) && (issue_response[:error] || issue_response['error'])

          issue = issue_response
          issues << {
            key: issue['key'],
            summary: issue['fields']['summary'],
            status: issue['fields']['status']['name'],
            assignee: issue['fields']['assignee']&.dig('displayName'),
            priority: issue['fields']['priority']&.dig('name'),
            issueType: issue['fields']['issuetype']['name'],
            url: "#{jira_site_url}/browse/#{issue['key']}",
            id: issue['key'], # Use key as ID for frontend compatibility
            commentId: issue_key # Use issue_key as commentId for backward compatibility
          }
        rescue StandardError => e
          Rails.logger.error("JIRA: Error fetching issue #{issue_key}: #{e.message}")
          # Continue with other issues
        end
      end

      { data: issues }
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

  private

  def jira_hook
    @jira_hook ||= account.hooks.find_by!(app_id: 'jira')
  end

  def jira_client
    @jira_client ||= begin
      hook_settings = jira_hook.settings
      auth_config = {
        site_url: jira_site_url,
        auth_type: hook_settings['auth_type'] || 'api_token'
      }
      
      case auth_config[:auth_type]
      when 'api_token'
        auth_config[:email] = hook_settings['email']
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
    return '' unless description_obj&.dig('content')

    # Extract plain text from Atlassian Document Format
    description_obj['content'].map do |content_block|
      next unless content_block['type'] == 'paragraph'

      content_block['content']&.map { |text_node| text_node['text'] }&.join(' ')
    end.compact.join("\n\n")
  end
end
