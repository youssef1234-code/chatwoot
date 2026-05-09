require 'jira-ruby'
require 'httparty'
require 'base64'

class Jira
  def initialize(auth_config)
    @auth_config = auth_config
    @site_url = normalize_site_url(auth_config[:site_url])
    @deployment_type = auth_config[:deployment_type] || 'data_center'
    @client = build_jira_client
  end

  def data_center?
    @deployment_type == 'data_center'
  end

  def cloud?
    @deployment_type == 'cloud'
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

  # Get all available statuses across all projects
  def statuses
    response = HTTParty.get(
      "#{@site_url}/rest/api/2/status",
      headers: auth_headers.merge({ 'Accept' => 'application/json' }),
      timeout: 30
    )

    if response.code.to_i >= 400
      error_message = parse_error_response(response)
      Rails.logger.error("JIRA: Get statuses failed: #{error_message}")
      return { error: error_message }
    end

    statuses = JSON.parse(response.body)
    # Return unique status names with category color from JIRA
    unique_statuses = statuses.map do |s|
      {
        'id' => s['id'],
        'name' => s['name'],
        'category' => s.dig('statusCategory', 'name'),
        'color_name' => s.dig('statusCategory', 'colorName')
      }
    end.uniq { |s| s['name'] }.sort_by { |s| s['name'] }
    unique_statuses
  rescue StandardError => e
    Rails.logger.error("JIRA get_statuses error: #{e.message}")
    { error: e.message }
  end

  # Get project metadata including issue types, priorities, and assignable users
  def project_metadata(project_key)
    raise ArgumentError, 'Missing project key' if project_key.blank?

    begin
      project = @client.Project.find(project_key)
      
      # Get issue types for the project (exclude sub-tasks)
      issue_types = get_project_issue_types(project_key)

      # Get project-specific priorities via createmeta (not global priorities)
      priorities = get_project_priorities(project_key, issue_types)

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

      # Add optional fields - handle Cloud vs Data Center user identifiers
      if params[:assignee_id].present?
        issue_data['fields']['assignee'] = if data_center?
                                              { 'name' => params[:assignee_id] }
                                            else
                                              { 'accountId' => params[:assignee_id] }
                                            end
      end

      # Set reporter to the Chatwoot user who created the issue.
      # Users creating/escalating issues will have accounts in JIRA.
      # For auto-created tickets (no user context), fall back to the integration admin email.
      reporter_email = params[:reporter_email].presence || params[:admin_email]
      if reporter_email.present?
        reporter = find_user_by_email(reporter_email)
        if reporter
          issue_data['fields']['reporter'] = if data_center?
                                                { 'name' => reporter['name'] || reporter['key'] }
                                              else
                                                { 'accountId' => reporter['accountId'] }
                                              end
          Rails.logger.info("JIRA: Setting reporter to #{reporter['displayName']} (#{reporter_email})")
        else
          Rails.logger.warn("JIRA: Could not find JIRA user for email #{reporter_email}, using default reporter (integration auth user)")
        end
      else
        Rails.logger.info("JIRA: No reporter email provided, issue will be created under the integration auth user")
      end

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
          'accountId' => user_data['accountId'] || user_data['name'] || user_data['key'],
          'name' => user_data['name'],
          'key' => user_data['key'],
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

  # Fetch onboarding status from ScriptRunner REST endpoint
  def onboarding_status(org_name)
    return { error: 'Organization name is required' } if org_name.blank?

    begin
      encoded_org = ERB::Util.url_encode(org_name)
      response = HTTParty.get(
        "#{@site_url}/rest/scriptrunner/latest/custom/onboarding-status?org=#{encoded_org}",
        headers: auth_headers.merge({
          'Accept' => 'application/json'
        }),
        timeout: 30
      )

      if response.code.to_i == 200
        data = response.parsed_response
        Rails.logger.info("JIRA: Onboarding status fetched for org '#{org_name}': #{data&.dig('progress', 'stage')}")
        { data: data }
      elsif response.code.to_i == 404
        Rails.logger.info("JIRA: Onboarding status 404 for org '#{org_name}' — org not found in ScriptRunner")
        { data: nil }
      else
        Rails.logger.error("JIRA: Onboarding status HTTP error for '#{org_name}': #{response.code} - #{response.body}")
        { error: "Failed to fetch onboarding status: HTTP #{response.code}" }
      end
    rescue StandardError => e
      Rails.logger.error("JIRA: Onboarding status error for '#{org_name}': #{e.message}")
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

  # Create a link between two JIRA issues (e.g. "Relates", "Blocks", "Duplicate")
  def create_issue_link(inward_issue_key, outward_issue_key, link_type_name = 'Relates')
    begin
      link_data = {
        'type' => { 'name' => link_type_name },
        'inwardIssue' => { 'key' => inward_issue_key },
        'outwardIssue' => { 'key' => outward_issue_key }
      }

      response = HTTParty.post(
        "#{@site_url}/rest/api/2/issueLink",
        headers: auth_headers.merge({
          'Content-Type' => 'application/json',
          'Accept' => 'application/json'
        }),
        body: link_data.to_json,
        timeout: 15
      )

      if response.code.to_i >= 400
        error_message = parse_error_response(response)
        Rails.logger.error("JIRA: Create issue link failed: #{error_message}")
        return { error: error_message }
      end

      Rails.logger.info("JIRA: Linked #{inward_issue_key} → #{outward_issue_key} (#{link_type_name})")
      { success: true }
    rescue StandardError => e
      Rails.logger.error("JIRA create_issue_link error: #{e.message}")
      { error: e.message }
    end
  end

  # Escalate: create a new issue in the 2nd line project, link it to the original 1st line issue
  def escalate_to_second_line(original_issue_key, target_project_key, target_issue_type_id = nil, reporter_email: nil)
    raise ArgumentError, 'Missing issue key' if original_issue_key.blank?
    raise ArgumentError, 'Missing target project key' if target_project_key.blank?

    begin
      # Get the original issue details
      original_issue = get_issue(original_issue_key)
      if original_issue.is_a?(Hash) && (original_issue[:error] || original_issue['error'])
        return { error: original_issue[:error] || original_issue['error'] }
      end

      fields = original_issue['fields']

      # Determine target issue type
      if target_issue_type_id.blank?
        current_type_name = fields['issuetype']['name']
        target_types = get_project_issue_types(target_project_key)
        matched_type = target_types.find { |t| t['name'] == current_type_name }
        target_issue_type_id = matched_type ? matched_type['id'] : target_types.first&.dig('id')
      end

      return { error: 'Could not determine target issue type' } if target_issue_type_id.blank?

      # Build description with reference to original issue
      original_description = fields['description'] || ''
      escalation_header = "Escalated from 1st line issue [#{original_issue_key}].\n\n"
      new_description = escalation_header + original_description

      # Create the new issue in the 2nd line project
      create_params = {
        project_key: target_project_key,
        summary: "[Escalated] #{fields['summary']}",
        description: new_description,
        issue_type_id: target_issue_type_id,
        reporter_email: reporter_email
      }

      # Preserve priority if possible
      if fields['priority'].present?
        create_params[:priority_id] = fields['priority']['id']
      end

      new_issue = create_issue(create_params)
      if new_issue.is_a?(Hash) && (new_issue[:error] || new_issue['error'])
        return { error: new_issue[:error] || new_issue['error'] }
      end

      new_key = new_issue['key']
      Rails.logger.info("JIRA: Created escalated issue #{new_key} in #{target_project_key} from #{original_issue_key}")

      # Link the two issues
      link_result = create_issue_link(new_key, original_issue_key, 'Relates')
      if link_result[:error]
        Rails.logger.warn("JIRA: Could not link #{new_key} ↔ #{original_issue_key}: #{link_result[:error]}")
      end

      # Add comment to the ORIGINAL issue referencing the new one
      add_comment(original_issue_key, "This issue has been escalated to 2nd line support: [#{new_key}]")

      # Add comment to the NEW issue referencing the original
      add_comment(new_key, "This issue was escalated from 1st line support issue: [#{original_issue_key}]")

      {
        success: true,
        original_issue_key: original_issue_key,
        new_issue_key: new_key,
        new_issue_id: new_issue['id'],
        target_project: target_project_key
      }
    rescue StandardError => e
      Rails.logger.error("JIRA escalate_to_second_line error: #{e.message}")
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

  # Build JIRA client with appropriate authentication
  def build_jira_client
    # Data Center may use context paths like /jira
    context = ''

    case @auth_config[:auth_type]
    when 'api_token'
      JIRA::Client.new({
        site: @site_url,
        context_path: context,
        auth_type: :basic,
        username: @auth_config[:email],
        password: @auth_config[:api_token]
      })
    when 'personal_access_token'
      # Data Center PATs use Bearer auth — don't set username/password so the gem
      # won't call request.basic_auth (which would overwrite our Bearer header)
      JIRA::Client.new({
        site: @site_url,
        context_path: context,
        auth_type: :basic,
        default_headers: { 'Authorization' => "Bearer #{@auth_config[:api_token]}" }
      })
    when 'oauth'
      JIRA::Client.new({
        site: @site_url,
        context_path: context,
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
    when 'personal_access_token'
      # Data Center PATs use Bearer token authentication
      { 'Authorization' => "Bearer #{@auth_config[:api_token]}" }
    when 'oauth'
      { 'Authorization' => "Bearer #{@auth_config[:access_token]}" }
    else
      {}
    end
  end

  # Parse error from JIRA HTTP response
  def parse_error_response(response)
    if response.parsed_response.is_a?(Hash) && response.parsed_response['errorMessages']
      response.parsed_response['errorMessages'].join(', ')
    elsif response.parsed_response.is_a?(Hash) && response.parsed_response['errors']
      response.parsed_response['errors'].values.join(', ')
    else
      "HTTP #{response.code}: #{response.message}"
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
          # Data Center uses 'name'/'key', Cloud uses 'accountId'
          user_id = if data_center?
                      user['name'] || user['key']
                    else
                      user['accountId']
                    end
          {
            'accountId' => user_id,
            'displayName' => user['displayName'],
            'emailAddress' => user['emailAddress'],
            'name' => user['name'],
            'key' => user['key']
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

  # Find a JIRA user by email address
  def find_user_by_email(email)
    return nil if email.blank?

    begin
      # Data Center and Cloud have different user search endpoints
      search_url = if data_center?
                     "#{@site_url}/rest/api/2/user/search?username=#{CGI.escape(email)}&maxResults=5"
                   else
                     "#{@site_url}/rest/api/2/user/search?query=#{CGI.escape(email)}&maxResults=5"
                   end

      response = HTTParty.get(
        search_url,
        headers: auth_headers.merge({
          'Content-Type' => 'application/json',
          'Accept' => 'application/json'
        }),
        timeout: 15
      )

      if response.code.to_i == 200
        users = response.parsed_response
        # Find exact email match
        matched_user = users.find { |u| u['emailAddress']&.downcase == email.downcase }
        if matched_user
          Rails.logger.info("JIRA: Found user by email #{email}: #{matched_user['displayName']}")
          return matched_user
        end
        # Fall back to first result if no exact match
        if users.any?
          Rails.logger.info("JIRA: Using first user result for email #{email}: #{users.first['displayName']}")
          return users.first
        end
      end

      Rails.logger.warn("JIRA: No user found for email #{email}")
      nil
    rescue StandardError => e
      Rails.logger.error("JIRA find_user_by_email error: #{e.message}")
      nil
    end
  end

  # Update the reporter on an existing JIRA issue
  def update_issue_reporter(issue_key, reporter_email)
    return { error: 'Missing issue key' } if issue_key.blank?
    return { error: 'Missing reporter email' } if reporter_email.blank?

    begin
      reporter = find_user_by_email(reporter_email)
      return { error: "Could not find JIRA user for email #{reporter_email}" } unless reporter

      reporter_field = if data_center?
                         { 'name' => reporter['name'] || reporter['key'] }
                       else
                         { 'accountId' => reporter['accountId'] }
                       end

      update_data = { 'fields' => { 'reporter' => reporter_field } }

      response = HTTParty.put(
        "#{@site_url}/rest/api/2/issue/#{issue_key}",
        headers: auth_headers.merge({
          'Content-Type' => 'application/json',
          'Accept' => 'application/json'
        }),
        body: update_data.to_json,
        timeout: 30
      )

      if response.code.to_i >= 400
        error_message = parse_error_response(response)
        Rails.logger.error("JIRA: Update reporter failed for #{issue_key}: #{error_message}")
        return { error: error_message }
      end

      Rails.logger.info("JIRA: Updated reporter on #{issue_key} to #{reporter['displayName']} (#{reporter_email})")
      { success: true, reporter: reporter['displayName'] }
    rescue StandardError => e
      Rails.logger.error("JIRA update_issue_reporter error: #{e.message}")
      { error: e.message }
    end
  end

  # Escalate (move) a JIRA issue from one project to another
  def move_issue_to_project(issue_key, target_project_key, target_issue_type_id = nil)
    raise ArgumentError, 'Missing issue key' if issue_key.blank?
    raise ArgumentError, 'Missing target project key' if target_project_key.blank?

    begin
      # First, get the current issue to preserve its data
      current_issue = get_issue(issue_key)
      if current_issue.is_a?(Hash) && (current_issue[:error] || current_issue['error'])
        return { error: current_issue[:error] || current_issue['error'] }
      end

      fields = current_issue['fields']

      # If no target issue type provided, try to use the same type or find a matching one
      if target_issue_type_id.blank?
        current_type_name = fields['issuetype']['name']
        target_types = get_project_issue_types(target_project_key)
        matched_type = target_types.find { |t| t['name'] == current_type_name }
        target_issue_type_id = matched_type ? matched_type['id'] : target_types.first&.dig('id')
      end

      return { error: 'Could not determine target issue type' } if target_issue_type_id.blank?

      # Move the issue by updating project and issue type
      move_data = {
        'fields' => {
          'project' => { 'key' => target_project_key },
          'issuetype' => { 'id' => target_issue_type_id }
        }
      }

      response = HTTParty.put(
        "#{@site_url}/rest/api/2/issue/#{issue_key}",
        headers: auth_headers.merge({
          'Content-Type' => 'application/json',
          'Accept' => 'application/json'
        }),
        body: move_data.to_json,
        timeout: 30
      )

      if response.code.to_i >= 400
        error_message = parse_error_response(response)
        Rails.logger.error("JIRA: Move issue failed: #{error_message}")
        return { error: error_message }
      end

      Rails.logger.info("JIRA: Successfully moved issue #{issue_key} to project #{target_project_key}")
      { success: true, issue_key: issue_key, target_project: target_project_key }
    rescue StandardError => e
      Rails.logger.error("JIRA move_issue_to_project error: #{e.message}")
      { error: e.message }
    end
  end

  # Get issue types for a specific project
  def get_project_issue_types(project_key)
    begin
      response = HTTParty.get(
        "#{@site_url}/rest/api/2/project/#{project_key}",
        headers: auth_headers.merge({
          'Content-Type' => 'application/json',
          'Accept' => 'application/json'
        }),
        timeout: 15
      )

      if response.code.to_i == 200
        project_data = response.parsed_response
        issue_types = project_data['issueTypes'] || []
        issue_types
          .reject { |t| t['subtask'] == true }
          .map { |t| { 'id' => t['id'], 'name' => t['name'] } }
      else
        []
      end
    rescue StandardError => e
      Rails.logger.error("JIRA get_project_issue_types error: #{e.message}")
      []
    end
  end

  # Get project-specific priorities via createmeta v2 API
  def get_project_priorities(project_key, issue_types)
    return fallback_global_priorities if issue_types.blank?

    begin
      # Use the first issue type to get allowed priorities
      issue_type_id = issue_types.first['id']
      response = HTTParty.get(
        "#{@site_url}/rest/api/2/issue/createmeta/#{project_key}/issuetypes/#{issue_type_id}",
        headers: auth_headers.merge({
          'Content-Type' => 'application/json',
          'Accept' => 'application/json'
        }),
        timeout: 15
      )

      if response.code.to_i == 200
        values = response.parsed_response['values'] || []
        priority_field = values.find { |f| f['fieldId'] == 'priority' }
        if priority_field && priority_field['allowedValues'].present?
          return priority_field['allowedValues'].map { |p| { 'id' => p['id'], 'name' => p['name'] } }
        end
      end

      # Fallback to global priorities if createmeta didn't work
      fallback_global_priorities
    rescue StandardError => e
      Rails.logger.error("JIRA get_project_priorities error: #{e.message}")
      fallback_global_priorities
    end
  end

  def fallback_global_priorities
    @client.Priority.all.map { |p| { 'id' => p.id, 'name' => p.name } }
  rescue StandardError => e
    Rails.logger.error("JIRA fallback_global_priorities error: #{e.message}")
    []
  end

  public

  # ---- Service Desk Customer Management ----

  # Find or create a customer in JIRA Service Management
  def find_or_create_customer(email, display_name)
    return nil if email.blank?

    begin
      # First try to find existing customer by email
      existing = find_user_by_email(email)
      return existing if existing

      # Create customer via Service Desk API
      customer_data = {
        'email' => email,
        'displayName' => display_name || email.split('@').first
      }

      response = HTTParty.post(
        "#{@site_url}/rest/servicedeskapi/customer",
        headers: auth_headers.merge({
          'Content-Type' => 'application/json',
          'Accept' => 'application/json',
          'X-ExperimentalApi' => 'opt-in'
        }),
        body: customer_data.to_json,
        timeout: 15
      )

      if response.code.to_i >= 200 && response.code.to_i < 300
        customer = response.parsed_response
        Rails.logger.info("JIRA: Created customer #{display_name} (#{email})")
        customer
      else
        Rails.logger.warn("JIRA: Failed to create customer #{email}: #{response.code} - #{response.body}")
        nil
      end
    rescue StandardError => e
      Rails.logger.error("JIRA find_or_create_customer error: #{e.message}")
      nil
    end
  end

  # Add customer as request participant to a Service Desk issue
  def add_request_participant(issue_key, customer_identifier)
    return nil if issue_key.blank? || customer_identifier.blank?

    begin
      # Get the service desk ID from the issue's project
      issue = get_issue(issue_key)
      return nil if issue.is_a?(Hash) && (issue[:error] || issue['error'])

      project_key = issue['fields']['project']['key']
      service_desk_id = get_service_desk_id(project_key)

      if service_desk_id.nil?
        Rails.logger.warn("JIRA: No service desk found for project #{project_key}, skipping participant add")
        return nil
      end

      # Get the request ID (issue ID for service desk)
      request_id = issue['id'] || issue_key

      # Build participant identifier based on deployment type
      participant_data = if data_center?
                           { 'usernames' => [customer_identifier] }
                         else
                           { 'accountIds' => [customer_identifier] }
                         end

      response = HTTParty.post(
        "#{@site_url}/rest/servicedeskapi/request/#{request_id}/participant",
        headers: auth_headers.merge({
          'Content-Type' => 'application/json',
          'Accept' => 'application/json',
          'X-ExperimentalApi' => 'opt-in'
        }),
        body: participant_data.to_json,
        timeout: 15
      )

      if response.code.to_i >= 200 && response.code.to_i < 300
        Rails.logger.info("JIRA: Added participant #{customer_identifier} to issue #{issue_key}")
        response.parsed_response
      else
        Rails.logger.warn("JIRA: Failed to add participant to #{issue_key}: #{response.code} - #{response.body}")
        nil
      end
    rescue StandardError => e
      Rails.logger.error("JIRA add_request_participant error: #{e.message}")
      nil
    end
  end

  # ---- Service Desk Organization Management ----

  # Find or create an organization in JIRA Service Management
  def find_or_create_organization(name)
    return nil if name.blank?

    begin
      # Search existing organizations
      existing_org = find_organization_by_name(name)
      return existing_org if existing_org

      # Create new organization
      response = HTTParty.post(
        "#{@site_url}/rest/servicedeskapi/organization",
        headers: auth_headers.merge({
          'Content-Type' => 'application/json',
          'Accept' => 'application/json',
          'X-ExperimentalApi' => 'opt-in'
        }),
        body: { 'name' => name }.to_json,
        timeout: 15
      )

      if response.code.to_i >= 200 && response.code.to_i < 300
        org = response.parsed_response
        Rails.logger.info("JIRA: Created organization '#{name}' with ID #{org['id']}")
        org
      else
        Rails.logger.warn("JIRA: Failed to create organization '#{name}': #{response.code} - #{response.body}")
        nil
      end
    rescue StandardError => e
      Rails.logger.error("JIRA find_or_create_organization error: #{e.message}")
      nil
    end
  end

  # Search for an organization by name
  def find_organization_by_name(name)
    return nil if name.blank?

    begin
      start_at = 0
      loop do
        response = HTTParty.get(
          "#{@site_url}/rest/servicedeskapi/organization",
          headers: auth_headers.merge({
            'Content-Type' => 'application/json',
            'Accept' => 'application/json',
            'X-ExperimentalApi' => 'opt-in'
          }),
          query: { start: start_at, limit: 50 },
          timeout: 15
        )

        break unless response.code.to_i == 200

        data = response.parsed_response
        values = data['values'] || []
        match = values.find { |o| o['name']&.downcase == name.downcase }
        return match if match

        # Check if there are more pages
        break if values.size < 50 || (data['isLastPage'] == true)

        start_at += values.size
      end

      nil
    rescue StandardError => e
      Rails.logger.error("JIRA find_organization_by_name error: #{e.message}")
      nil
    end
  end

  # Add an organization to a service desk
  def add_organization_to_service_desk(service_desk_id, organization_id)
    return nil if service_desk_id.blank? || organization_id.blank?

    begin
      response = HTTParty.post(
        "#{@site_url}/rest/servicedeskapi/servicedesk/#{service_desk_id}/organization",
        headers: auth_headers.merge({
          'Content-Type' => 'application/json',
          'Accept' => 'application/json',
          'X-ExperimentalApi' => 'opt-in'
        }),
        body: { 'organizationId' => organization_id.to_i }.to_json,
        timeout: 15
      )

      if response.code.to_i >= 200 && response.code.to_i < 300
        Rails.logger.info("JIRA: Added organization #{organization_id} to service desk #{service_desk_id}")
        true
      else
        Rails.logger.warn("JIRA: Failed to add organization to service desk: #{response.code} - #{response.body}")
        false
      end
    rescue StandardError => e
      Rails.logger.error("JIRA add_organization_to_service_desk error: #{e.message}")
      false
    end
  end

  # Add an organization to a Service Desk request/issue
  def add_organization_to_request(issue_key, organization_id)
    return nil if issue_key.blank? || organization_id.blank?

    begin
      # Get the issue to find its ID
      issue = get_issue(issue_key)
      return nil if issue.is_a?(Hash) && (issue[:error] || issue['error'])

      request_id = issue['id'] || issue_key

      response = HTTParty.post(
        "#{@site_url}/rest/servicedeskapi/request/#{request_id}/organization",
        headers: auth_headers.merge({
          'Content-Type' => 'application/json',
          'Accept' => 'application/json',
          'X-ExperimentalApi' => 'opt-in'
        }),
        body: { 'organizationId' => organization_id.to_i }.to_json,
        timeout: 15
      )

      if response.code.to_i >= 200 && response.code.to_i < 300
        Rails.logger.info("JIRA: Added organization #{organization_id} to request #{issue_key}")
        true
      else
        # If the request-level endpoint doesn't exist (Data Center), try updating the Organizations custom field
        Rails.logger.warn("JIRA: request org endpoint returned #{response.code}, trying custom field update")
        add_organization_via_custom_field(issue_key, organization_id)
      end
    rescue StandardError => e
      Rails.logger.error("JIRA add_organization_to_request error: #{e.message}")
      false
    end
  end

  # Fallback: set the Organizations custom field on the issue directly
  def add_organization_via_custom_field(issue_key, organization_id)
    begin
      # Find the Organizations custom field ID
      org_field_id = find_organizations_custom_field
      return false unless org_field_id

      # Get current organizations on the issue
      issue = get_issue(issue_key)
      return false if issue.is_a?(Hash) && (issue[:error] || issue['error'])

      current_orgs = issue.dig('fields', org_field_id) || []
      current_ids = current_orgs.map { |o| o['id'].to_i }

      # Don't add if already present
      return true if current_ids.include?(organization_id.to_i)

      # JIRA DC Organizations field expects an array of integer IDs
      new_ids = current_ids + [organization_id.to_i]

      update_data = {
        'fields' => {
          org_field_id => new_ids
        }
      }

      response = HTTParty.put(
        "#{@site_url}/rest/api/2/issue/#{issue_key}",
        headers: auth_headers.merge({
          'Content-Type' => 'application/json',
          'Accept' => 'application/json'
        }),
        body: update_data.to_json,
        timeout: 15
      )

      if response.code.to_i >= 200 && response.code.to_i < 300
        Rails.logger.info("JIRA: Set Organizations field on #{issue_key} via custom field #{org_field_id}")
        true
      else
        Rails.logger.warn("JIRA: Failed to set Organizations field on #{issue_key}: #{response.code} - #{response.body}")
        false
      end
    rescue StandardError => e
      Rails.logger.error("JIRA add_organization_via_custom_field error: #{e.message}")
      false
    end
  end

  # Remove an organization from a Service Desk request/issue
  def remove_organization_from_request(issue_key, organization_id)
    return nil if issue_key.blank? || organization_id.blank?

    begin
      issue = get_issue(issue_key)
      return nil if issue.is_a?(Hash) && (issue[:error] || issue['error'])

      request_id = issue['id'] || issue_key

      response = HTTParty.delete(
        "#{@site_url}/rest/servicedeskapi/request/#{request_id}/organization",
        headers: auth_headers.merge({
          'Content-Type' => 'application/json',
          'Accept' => 'application/json',
          'X-ExperimentalApi' => 'opt-in'
        }),
        body: { 'organizationId' => organization_id.to_i }.to_json,
        timeout: 15
      )

      if response.code.to_i >= 200 && response.code.to_i < 300
        Rails.logger.info("JIRA: Removed organization #{organization_id} from request #{issue_key}")
        true
      else
        # Fallback: remove from the Organizations custom field directly
        Rails.logger.warn("JIRA: SD request org removal returned #{response.code}, trying custom field update")
        remove_organization_via_custom_field(issue_key, organization_id)
      end
    rescue StandardError => e
      Rails.logger.error("JIRA remove_organization_from_request error: #{e.message}")
      false
    end
  end

  # Fallback: remove an organization from the custom field on the issue
  def remove_organization_via_custom_field(issue_key, organization_id)
    begin
      org_field_id = find_organizations_custom_field
      return false unless org_field_id

      issue = get_issue(issue_key)
      return false if issue.is_a?(Hash) && (issue[:error] || issue['error'])

      current_orgs = issue.dig('fields', org_field_id) || []
      current_ids = current_orgs.map { |o| o['id'].to_i }

      new_ids = current_ids - [organization_id.to_i]

      # Nothing to remove
      return true if current_ids == new_ids

      update_data = {
        'fields' => {
          org_field_id => new_ids
        }
      }

      response = HTTParty.put(
        "#{@site_url}/rest/api/2/issue/#{issue_key}",
        headers: auth_headers.merge({
          'Content-Type' => 'application/json',
          'Accept' => 'application/json'
        }),
        body: update_data.to_json,
        timeout: 15
      )

      if response.code.to_i >= 200 && response.code.to_i < 300
        Rails.logger.info("JIRA: Removed org #{organization_id} from #{issue_key} via custom field #{org_field_id}")
        true
      else
        Rails.logger.warn("JIRA: Failed to remove org from #{issue_key}: #{response.code} - #{response.body}")
        false
      end
    rescue StandardError => e
      Rails.logger.error("JIRA remove_organization_via_custom_field error: #{e.message}")
      false
    end
  end

  # Find the custom field ID for Organizations (Service Desk field)
  def find_organizations_custom_field
    @organizations_field_id ||= begin
      response = HTTParty.get(
        "#{@site_url}/rest/api/2/field",
        headers: auth_headers.merge({
          'Content-Type' => 'application/json',
          'Accept' => 'application/json'
        }),
        timeout: 15
      )

      if response.code.to_i == 200
        fields = response.parsed_response
        org_field = fields.find { |f| f['name'] == 'Organizations' || f['clauseNames']&.include?('organizations') }
        org_field&.dig('id')
      else
        nil
      end
    end
  end

  # Get the service desk ID for a project
  def get_service_desk_id(project_key)
    begin
      start_at = 0
      loop do
        response = HTTParty.get(
          "#{@site_url}/rest/servicedeskapi/servicedesk",
          headers: auth_headers.merge({
            'Content-Type' => 'application/json',
            'Accept' => 'application/json',
            'X-ExperimentalApi' => 'opt-in'
          }),
          query: { start: start_at, limit: 50 },
          timeout: 15
        )

        break unless response.code.to_i == 200

        data = response.parsed_response
        desks = data['values'] || []
        desk = desks.find { |d| d['projectKey'] == project_key }
        return desk['id'] if desk

        break if desks.size < 50 || (data['isLastPage'] == true)

        start_at += desks.size
      end

      nil
    rescue StandardError => e
      Rails.logger.error("JIRA get_service_desk_id error: #{e.message}")
      nil
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
