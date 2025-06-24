require 'jira-ruby'
require 'httparty'
require 'base64'

class Jira
  def initialize(auth_config)
    @auth_config = auth_config
    @site_url = normalize_site_url(auth_config[:site_url])
    @client = build_jira_client
  end

  def self.client(auth_config)
    new(auth_config)
  end

  def client
    @client
  end

  # Get all accessible projects
  def projects
    begin
      # First check authentication
      user_info = current_user
      if user_info['error']
        return { error: user_info['error'] }
      end
      
      projects = @client.Project.all
      
      # If no projects, try alternative API call
      if projects.empty?
        response = @client.get('/rest/api/2/project')
        if response.code.to_i == 200
          project_data = JSON.parse(response.body)
          return project_data.map do |project|
            {
              'id' => project['id'],
              'key' => project['key'],
              'name' => project['name'],
              'description' => project['description']&.strip,
              'projectTypeKey' => project['projectTypeKey']
            }
          end
        end
      end
      
      result = projects.map do |project|
        # Safely access description - some projects may not have one or it may not be loaded
        description = nil
        begin
          description = project.respond_to?(:description) ? project.description&.strip : nil
        rescue => e
          Rails.logger.debug("JIRA: Could not access description for project #{project.key}: #{e.message}")
        end
        
        {
          'id' => project.id,
          'key' => project.key,
          'name' => project.name,
          'description' => description,
          'projectTypeKey' => project.respond_to?(:projectTypeKey) ? project.projectTypeKey : nil
        }
      end
      
      result
    rescue StandardError => e
      Rails.logger.error("JIRA get_projects error: #{e.message}")
      { error: e.message }
    end
  end

  # Get project metadata including issue types, priorities, and assignable users
  def project_metadata(project_key)
    raise ArgumentError, 'Missing project key' if project_key.blank?

    begin
      project = @client.Project.find(project_key)
      
      # Get issue types for the project
      issue_types = @client.Issuetype.all.map do |type|
        {
          'id' => type.id,
          'name' => type.name,
          'description' => type.description
        }
      end

      # Get priorities
      priorities = @client.Priority.all.map do |priority|
        {
          'id' => priority.id,
          'name' => priority.name
        }
      end

      # Get assignable users
      users = get_assignable_users(project_key)

      {
        'project' => {
          'id' => project.id,
          'key' => project.key,
          'name' => project.name
        },
        'issue_types' => issue_types,
        'priorities' => priorities,
        'users' => users
      }
    rescue StandardError => e
      Rails.logger.error("JIRA get_project_metadata error: #{e.message}")
      { error: e.message }
    end
  end

  # Create a new JIRA issue
  def create_issue(params)
    validate_required_params(params)

    begin
      issue_data = {
        'fields' => {
          'project' => { 'key' => params[:project_key] },
          'summary' => params[:summary],
          'description' => params[:description] || '',
          'issuetype' => { 'id' => params[:issue_type_id] }
        }
      }

      # Add optional fields
      issue_data['fields']['assignee'] = { 'accountId' => params[:assignee_id] } if params[:assignee_id].present?
      issue_data['fields']['priority'] = { 'id' => params[:priority_id] } if params[:priority_id].present?
      issue_data['fields']['labels'] = params[:labels] if params[:labels].present?

      Rails.logger.info("JIRA: Creating issue with data: #{issue_data.to_json}")

      # Use HTTParty for more reliable API calls
      response = HTTParty.post(
        "#{@site_url}/rest/api/2/issue",
        headers: auth_headers.merge({
          'Content-Type' => 'application/json',
          'Accept' => 'application/json'
        }),
        body: issue_data.to_json,
        timeout: 30
      )
      
      Rails.logger.info("JIRA: Create issue response code: #{response.code}")
      Rails.logger.info("JIRA: Create issue response body: #{response.body}")
      
      if response.code.to_i >= 400
        error_message = if response.parsed_response.is_a?(Hash) && response.parsed_response['errorMessages']
                          response.parsed_response['errorMessages'].join(', ')
                        elsif response.parsed_response.is_a?(Hash) && response.parsed_response['errors']
                          response.parsed_response['errors'].values.join(', ')
                        else
                          "HTTP #{response.code}: #{response.message}"
                        end
        Rails.logger.error("JIRA: Create issue failed: #{error_message}")
        return { error: error_message }
      end

      issue_response = response.parsed_response
      
      # Return the created issue data
      result = {
        'id' => issue_response['id'],
        'key' => issue_response['key'],
        'self' => issue_response['self']
      }
      
      Rails.logger.info("JIRA: Successfully created issue: #{result}")
      result
    rescue StandardError => e
      Rails.logger.error("JIRA create_issue error: #{e.message}")
      Rails.logger.error("JIRA create_issue backtrace: #{e.backtrace}")
      { error: e.message }
    end
  end

  # Get a specific issue by key
  def get_issue(issue_key)
    raise ArgumentError, 'Missing issue key' if issue_key.blank?

    begin
      issue = @client.Issue.find(issue_key)
      {
        'id' => issue.id,
        'key' => issue.key,
        'self' => issue.self,
        'fields' => issue.fields
      }
    rescue StandardError => e
      Rails.logger.error("JIRA get_issue error: #{e.message}")
      { error: e.message }
    end
  end

  # Search for issues using JQL
  def search_issue(query)
    raise ArgumentError, 'Missing query' if query.blank?

    begin
      # Build a comprehensive JQL query that searches multiple fields
      escaped_query = query.gsub('"', '\\"')
      
      # Try different search strategies
      jql_queries = []
      
      # Check if query looks like an issue key (e.g., PROJ-123)
      if query.match?(/^[A-Z]+-\d+$/i)
        jql_queries << "key = \"#{escaped_query}\""
      end
      
      # Always include text searches
      jql_queries << "summary ~ \"#{escaped_query}\""
      jql_queries << "description ~ \"#{escaped_query}\""
      
      # Try broader searches if the term is long enough
      if query.length >= 3
        jql_queries << "text ~ \"#{escaped_query}\""  # Full-text search if available
      end
      
      jql = jql_queries.join(" OR ")
      
      Rails.logger.info("JIRA search JQL: #{jql}")
      
      # Try the search with error handling for different JIRA configurations
      issues = []
      begin
        issues = @client.Issue.jql(jql, max_results: 50)
      rescue => jql_error
        Rails.logger.warn("Primary JQL search failed: #{jql_error.message}")
        
        # Fallback to simpler search
        simple_jql = "summary ~ \"#{escaped_query}\""
        Rails.logger.info("Trying fallback JQL: #{simple_jql}")
        
        begin
          issues = @client.Issue.jql(simple_jql, max_results: 50)
        rescue => fallback_error
          Rails.logger.error("Fallback search also failed: #{fallback_error.message}")
          raise fallback_error
        end
      end
      
      result = issues.map do |issue|
        {
          'id' => issue.id,
          'key' => issue.key,
          'summary' => issue.fields['summary'],
          'status' => issue.fields['status']&.dig('name') || 'Unknown',
          'issueType' => issue.fields['issuetype']&.dig('name') || 'Unknown',
          'priority' => issue.fields['priority']&.dig('name'),
          'assignee' => issue.fields['assignee']&.dig('displayName'),
          'url' => "#{@site_url}/browse/#{issue.key}",
          'fields' => {
            'summary' => issue.fields['summary'],
            'status' => issue.fields['status'],
            'issuetype' => issue.fields['issuetype'],
            'priority' => issue.fields['priority'],
            'assignee' => issue.fields['assignee']
          }
        }
      end
      
      # Sort by numeric ID from JIRA key in descending order (newest first)
      result.sort! do |a, b|
        # Extract numeric ID from JIRA key (e.g., "PROJ-123" -> 123)
        get_numeric_id = ->(key) { 
          match = key.match(/-(\d+)$/)
          match ? match[1].to_i : 0
        }
        get_numeric_id.call(b['key']) <=> get_numeric_id.call(a['key'])
      end
      
      Rails.logger.info("JIRA search found #{result.length} issues")
      result
    rescue StandardError => e
      Rails.logger.error("JIRA search_issue error: #{e.message}")
      Rails.logger.error("Query: #{query}")
      { error: e.message }
    end
  end

  # Find issues linked to a specific URL
  def linked_issues(url)
    raise ArgumentError, 'Missing link' if url.blank?

    begin
      Rails.logger.info("JIRA: Searching for issues linked to URL: #{url}")
      
      # Search for issues that contain the URL in comments
      escaped_url = url.gsub('"', '\\"')
      jql_query = "comment ~ \"#{escaped_url}\""
      
      Rails.logger.info("JIRA: Using JQL query: #{jql_query}")
      
      issues = @client.Issue.jql(jql_query, max_results: 50)
      Rails.logger.info("JIRA: Found #{issues.length} issues")
      
      result = issues.map do |issue|
        # Find the comment ID and creation date that contains the URL
        comment_info = find_comment_with_url(issue, url)
        
        Rails.logger.info("JIRA: Issue #{issue.key} has comment_id: #{comment_info[:comment_id] || 'nil'} created at: #{comment_info[:created_at] || 'nil'}")
        
        {
          'id' => issue.id,
          'key' => issue.key,
          'fields' => issue.fields,
          'comment_id' => comment_info[:comment_id],
          'linked_at' => comment_info[:created_at]
        }
      end
      
      # Sort by comment creation date in descending order (most recently linked first)
      result.sort! do |a, b|
        # Handle cases where linked_at might be nil
        date_a = a['linked_at'] ? Time.parse(a['linked_at']) : Time.new(0)
        date_b = b['linked_at'] ? Time.parse(b['linked_at']) : Time.new(0)
        date_b <=> date_a
      end
      
      Rails.logger.info("JIRA: Returning #{result.length} linked issues sorted by link date")
      result
    rescue StandardError => e
      Rails.logger.error("JIRA linked_issues error: #{e.message}")
      { error: e.message }
    end
  end

  # Link an issue to a Chatwoot conversation by adding a comment
  def link_issue(issue_key, url, title)
    raise ArgumentError, 'Missing issue key' if issue_key.blank?
    raise ArgumentError, 'Missing link' if url.blank?

    begin
      # Create comment text with link
      comment_text = "Linked to Chatwoot conversation: [#{title || 'Conversation'}|#{url}]"
      add_comment(issue_key, comment_text)
    rescue StandardError => e
      Rails.logger.error("JIRA link_issue error: #{e.message}")
      { error: e.message }
    end
  end

  # Unlink an issue by deleting the comment
  def unlink_issue(issue_key, comment_id)
    raise ArgumentError, 'Missing issue key' if issue_key.blank?
    raise ArgumentError, 'Missing comment id' if comment_id.blank?

    begin
      delete_comment(issue_key, comment_id)
    rescue StandardError => e
      Rails.logger.error("JIRA unlink_issue error: #{e.message}")
      { error: e.message }
    end
  end

  # Add a comment to an issue
  def add_comment(issue_key, comment_body)
    raise ArgumentError, 'Missing issue key' if issue_key.blank?
    raise ArgumentError, 'Missing comment body' if comment_body.blank?

    begin
      comment_data = {
        'body' => comment_body
      }

      Rails.logger.info("JIRA: Adding comment to issue #{issue_key} with body: #{comment_body}")

      # Use HTTParty for more reliable API calls
      response = HTTParty.post(
        "#{@site_url}/rest/api/2/issue/#{issue_key}/comment",
        headers: auth_headers.merge({
          'Content-Type' => 'application/json',
          'Accept' => 'application/json'
        }),
        body: comment_data.to_json,
        timeout: 30
      )
      
      Rails.logger.info("JIRA: Add comment response code: #{response.code}")
      Rails.logger.info("JIRA: Add comment response body: #{response.body}")
      
      if response.code.to_i >= 400
        error_message = if response.parsed_response.is_a?(Hash) && response.parsed_response['errorMessages']
                          response.parsed_response['errorMessages'].join(', ')
                        elsif response.parsed_response.is_a?(Hash) && response.parsed_response['errors']
                          response.parsed_response['errors'].values.join(', ')
                        else
                          "HTTP #{response.code}: #{response.message}"
                        end
        Rails.logger.error("JIRA: Add comment failed: #{error_message}")
        return { error: error_message }
      end

      comment_response = response.parsed_response
      
      result = {
        'id' => comment_response['id'],
        'body' => comment_response['body'],
        'created' => comment_response['created'],
        'author' => comment_response['author']
      }
      
      Rails.logger.info("JIRA: Successfully added comment: #{result}")
      result
    rescue StandardError => e
      Rails.logger.error("JIRA add_comment error: #{e.message}")
      Rails.logger.error("JIRA add_comment backtrace: #{e.backtrace}")
      { error: e.message }
    end
  end

  # Get comments for an issue
  def get_comments(issue_key)
    raise ArgumentError, 'Missing issue key' if issue_key.blank?

    begin
      issue = @client.Issue.find(issue_key)
      comments = issue.comments.map do |comment|
        {
          'id' => comment.id,
          'body' => comment.body,
          'created' => comment.created,
          'updated' => comment.updated,
          'author' => {
            'displayName' => comment.author['displayName'],
            'emailAddress' => comment.author['emailAddress']
          }
        }
      end
      comments
    rescue StandardError => e
      Rails.logger.error("JIRA get_comments error: #{e.message}")
      { error: e.message }
    end
  end

  # Delete a comment
  def delete_comment(issue_key, comment_id)
    raise ArgumentError, 'Missing issue key' if issue_key.blank?
    raise ArgumentError, 'Missing comment id' if comment_id.blank?

    begin
      Rails.logger.info("JIRA: Deleting comment #{comment_id} from issue #{issue_key}")
      
      # Use HTTParty to delete the comment
      response = HTTParty.delete(
        "#{@site_url}/rest/api/2/issue/#{issue_key}/comment/#{comment_id}",
        headers: auth_headers,
        timeout: 30
      )
      
      Rails.logger.info("JIRA: Delete comment response code: #{response.code}")
      
      if response.code.to_i >= 400
        error_message = if response.parsed_response.is_a?(Hash) && response.parsed_response['errorMessages']
                          response.parsed_response['errorMessages'].join(', ')
                        elsif response.parsed_response.is_a?(Hash) && response.parsed_response['errors']
                          response.parsed_response['errors'].values.join(', ')
                        else
                          "HTTP #{response.code}: #{response.message}"
                        end
        
        Rails.logger.error("JIRA: Delete comment failed: #{error_message}")
        return { error: error_message }
      end
      
      { success: true }
    rescue StandardError => e
      Rails.logger.error("JIRA delete_comment error: #{e.message}")
      { error: e.message }
    end
  end

  # Add attachment to an issue
  def add_attachment(issue_key, file_path, _filename = nil)
    raise ArgumentError, 'Missing issue key' if issue_key.blank?
    raise ArgumentError, 'Missing file path' if file_path.blank?
    raise ArgumentError, 'File does not exist' unless File.exist?(file_path)

    begin
      Rails.logger.info("JIRA: Adding attachment to issue #{issue_key}, file: #{file_path}")
      
      # Use HTTParty for multipart upload
      response = HTTParty.post(
        "#{@site_url}/rest/api/2/issue/#{issue_key}/attachments",
        headers: auth_headers.merge({
          'X-Atlassian-Token' => 'no-check'
        }),
        body: {
          file: File.open(file_path, 'rb')
        },
        timeout: 60
      )
      
      Rails.logger.info("JIRA: Add attachment response code: #{response.code}")
      Rails.logger.info("JIRA: Add attachment response body: #{response.body}")
      
      if response.code.to_i >= 400
        error_message = if response.parsed_response.is_a?(Hash) && response.parsed_response['errorMessages']
                          response.parsed_response['errorMessages'].join(', ')
                        elsif response.parsed_response.is_a?(Hash) && response.parsed_response['errors']
                          response.parsed_response['errors'].values.join(', ')
                        else
                          "HTTP #{response.code}: #{response.message}"
                        end
        Rails.logger.error("JIRA: Add attachment failed: #{error_message}")
        return { error: error_message }
      end

      attachments = response.parsed_response
      
      if attachments.is_a?(Array) && attachments.first
        attachment = attachments.first
        result = {
          'id' => attachment['id'],
          'filename' => attachment['filename'],
          'size' => attachment['size'],
          'created' => attachment['created'],
          'content' => attachment['content']
        }
        Rails.logger.info("JIRA: Successfully added attachment: #{result}")
        result
      else
        Rails.logger.error("JIRA: Unexpected attachment response format: #{attachments}")
        { error: 'Failed to upload attachment - unexpected response format' }
      end
    rescue StandardError => e
      Rails.logger.error("JIRA add_attachment error: #{e.message}")
      Rails.logger.error("JIRA add_attachment backtrace: #{e.backtrace}")
      { error: e.message }
    end
  end

  # Test authentication and get current user info
  def current_user
    begin
      # Try to get current user info to verify authentication
      response = @client.get('/rest/api/2/myself')
      if response.code.to_i == 200
        user_data = JSON.parse(response.body)
        Rails.logger.info("JIRA: Authenticated as user: #{user_data['displayName']} (#{user_data['emailAddress']})")
        {
          'accountId' => user_data['accountId'],
          'displayName' => user_data['displayName'],
          'emailAddress' => user_data['emailAddress'],
          'groups' => user_data['groups'] || [],
          'applicationRoles' => user_data['applicationRoles'] || []
        }
      else
        Rails.logger.error("JIRA current_user HTTP error: #{response.code} - #{response.body}")
        { error: "Authentication failed: #{response.code}" }
      end
    rescue StandardError => e
      Rails.logger.error("JIRA current_user error: #{e.message}")
      { error: e.message }
    end
  end

  # Convenience class methods for backward compatibility
  def self.search_issues(access_token, site_url, query)
    client = new(access_token, site_url)
    result = client.search_issue(query)
    result.is_a?(Hash) && result[:error] ? [] : result
  end

  def self.get_projects(access_token, site_url)
    client = new(access_token, site_url)
    result = client.projects
    result.is_a?(Hash) && result[:error] ? [] : result
  end

  def self.create_issue(access_token, site_url, params)
    client = new(access_token, site_url)
    client.create_issue(params)
  end

  def self.add_comment_to_issue(access_token, site_url, issue_key, comment_body)
    client = new(access_token, site_url)
    client.add_comment(issue_key, comment_body)
  end

  def self.update_issue_labels(access_token, site_url, issue_key, labels)
    client = new(access_token, site_url)
    client.update_issue_labels(issue_key, labels)
  end

  # Update labels on an existing JIRA issue
  def update_issue_labels(issue_key, labels)
    raise ArgumentError, 'Missing issue key' if issue_key.blank?
    
    begin
      Rails.logger.info("JIRA: Updating labels for issue #{issue_key} with: #{labels}")
      
      # Prepare the update data
      update_data = {
        'fields' => {
          'labels' => labels || []
        }
      }

      # Use HTTParty to update the issue
      response = HTTParty.put(
        "#{@site_url}/rest/api/2/issue/#{issue_key}",
        headers: auth_headers.merge({
          'Content-Type' => 'application/json',
          'Accept' => 'application/json'
        }),
        body: update_data.to_json,
        timeout: 30
      )
      
      Rails.logger.info("JIRA: Update labels response code: #{response.code}")
      
      if response.code.to_i >= 400
        error_message = if response.parsed_response.is_a?(Hash) && response.parsed_response['errorMessages']
                          response.parsed_response['errorMessages'].join(', ')
                        elsif response.parsed_response.is_a?(Hash) && response.parsed_response['errors']
                          response.parsed_response['errors'].values.join(', ')
                        else
                          "HTTP #{response.code}: #{response.message}"
                        end
        
        Rails.logger.error("JIRA: Update labels failed: #{error_message}")
        return { error: error_message }
      end
      
      { success: true, labels: labels }
    rescue StandardError => e
      Rails.logger.error("JIRA update_issue_labels error: #{e.message}")
      { error: e.message }
    end
  end

  private

  # Normalize site URL to ensure proper format
  def normalize_site_url(url)
    return url if url.blank?
    
    url = url.strip
    url = "https://#{url}" unless url.start_with?('http')
    url.chomp('/')
  end

  # Validate required parameters for issue creation
  def validate_required_params(params)
    raise ArgumentError, 'Missing project key' if params[:project_key].blank?
    raise ArgumentError, 'Missing summary' if params[:summary].blank?
    raise ArgumentError, 'Missing issue type' if params[:issue_type_id].blank?
  end

  # Build JIRA client with API token authentication
  def build_jira_client
    case @auth_config[:auth_type]
    when 'api_token'
      JIRA::Client.new({
        site: @site_url,
        context_path: '',
        auth_type: :basic,
        username: @auth_config[:email],
        password: @auth_config[:api_token]
      })
    when 'oauth'
      JIRA::Client.new({
        site: @site_url,
        context_path: '',
        auth_type: :oauth_2,
        access_token: @auth_config[:access_token]
      })
    else
      raise ArgumentError, "Unsupported auth type: #{@auth_config[:auth_type]}"
    end
  end

  # Get appropriate authorization headers for HTTP requests
  def auth_headers
    case @auth_config[:auth_type]
    when 'api_token'
      encoded_credentials = Base64.strict_encode64("#{@auth_config[:email]}:#{@auth_config[:api_token]}")
      { 'Authorization' => "Basic #{encoded_credentials}" }
    when 'oauth'
      { 'Authorization' => "Bearer #{@auth_config[:access_token]}" }
    else
      {}
    end
  end

  # Get assignable users for a project
  def get_assignable_users(project_key)
    begin
      # Use REST API v2 for assignable users with basic auth
      response = HTTParty.get(
        "#{@site_url}/rest/api/2/user/assignable/search?project=#{project_key}&maxResults=20",
        headers: auth_headers.merge({
          'Content-Type' => 'application/json',
          'Accept' => 'application/json'
        })
      )

      if response.code.to_i == 200
        users_data = response.parsed_response
        users_data.map do |user|
          {
            'accountId' => user['accountId'],
            'displayName' => user['displayName'],
            'emailAddress' => user['emailAddress']
          }
        end
      else
        Rails.logger.error("JIRA get_assignable_users HTTP error: #{response.code} - #{response.body}")
        []
      end
    rescue StandardError => e
      Rails.logger.error("JIRA get_assignable_users error: #{e.message}")
      []
    end
  end

  # Find comment ID and creation date that contains a specific URL
  def find_comment_with_url(issue, url)
    begin
      Rails.logger.info("JIRA: Looking for comment with URL '#{url}' in issue #{issue.key}")
      
      if issue.comments.nil? || issue.comments.empty?
        Rails.logger.warn("JIRA: No comments found for issue #{issue.key}")
        return { comment_id: nil, created_at: nil }
      end
      
      issue.comments.each do |comment|
        if comment.body&.include?(url)
          Rails.logger.info("JIRA: Found matching comment #{comment.id} in issue #{issue.key}")
          return {
            comment_id: comment.id,
            created_at: comment.created
          }
        end
      end
      
      Rails.logger.warn("JIRA: No comment containing URL found in issue #{issue.key}")
      { comment_id: nil, created_at: nil }
    rescue StandardError => e
      Rails.logger.error("JIRA find_comment_with_url error for issue #{issue.key}: #{e.message}")
      { comment_id: nil, created_at: nil }
    end
  end
end
