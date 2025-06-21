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

  def link_issue(url, issue_key, title)
    response = jira_client.link_issue(issue_key, url, title)
    
    # Handle error responses (can have string or symbol keys)
    if response.is_a?(Hash) && (response[:error] || response['error'])
      return response
    end

    {
      data: {
        issue_key: issue_key,
        url: url,
        comment_id: response['id']
      }
    }
  end

  def unlink_issue(issue_key, comment_id)
    response = jira_client.unlink_issue(issue_key, comment_id)
    
    # Handle error responses (can have string or symbol keys)
    if response.is_a?(Hash) && (response[:error] || response['error'])
      return response
    end

    {
      data: { issue_key: issue_key, comment_id: comment_id }
    }
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

  def linked_issues(url)
    response = jira_client.linked_issues(url)
    
    # Handle error responses (can have string or symbol keys)
    if response.is_a?(Hash) && (response[:error] || response['error'])
      return response
    end

    # Handle successful response (array of issues)
    issues_array = response.is_a?(Array) ? response : []
    issues = issues_array.map do |issue|
      {
        key: issue['key'],
        summary: issue['fields']['summary'],
        status: issue['fields']['status']['name'],
        assignee: issue['fields']['assignee']&.dig('displayName'),
        priority: issue['fields']['priority']&.dig('name'),
        issueType: issue['fields']['issuetype']['name'],
        url: "#{jira_site_url}/browse/#{issue['key']}",
        id: issue['key'] # Use key as ID for frontend compatibility
      }
    end

    { data: issues }
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
