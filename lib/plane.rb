require 'httparty'
require 'json'

class Plane
  BASE_TIMEOUT = 30

  def initialize(auth_config)
    @auth_config = auth_config
    @base_url = normalize_base_url(auth_config[:base_url])
    @api_key = auth_config[:api_key]
    @workspace_slug = auth_config[:workspace_slug]
  end

  def self.client(auth_config)
    new(auth_config)
  end

  # Verify connection and get current user info
  def current_user
    response = make_request(:get, '/api/v1/users/me/')
    
    if response.success?
      response.parsed_response
    else
      { 'error' => parse_error(response) }
    end
  rescue StandardError => e
    Rails.logger.error("Plane current_user error: #{e.message}")
    { 'error' => e.message }
  end

  # Get all accessible workspaces
  def workspaces
    response = make_request(:get, '/api/v1/workspaces/')
    
    if response.success?
      response.parsed_response.fetch('results', response.parsed_response)
    else
      { error: parse_error(response) }
    end
  rescue StandardError => e
    Rails.logger.error("Plane workspaces error: #{e.message}")
    { error: e.message }
  end

  # Get all projects in the workspace
  def projects
    response = make_request(:get, "/api/v1/workspaces/#{@workspace_slug}/projects/")
    
    if response.success?
      data = response.parsed_response
      projects_array = data.is_a?(Hash) ? data.fetch('results', []) : data
      projects_array.map do |project|
        {
          'id' => project['id'],
          'name' => project['name'],
          'identifier' => project['identifier'],
          'description' => project['description'],
          'cover_image' => project['cover_image'],
          'icon_prop' => project['icon_prop'],
          'network' => project['network'],
          'created_at' => project['created_at']
        }
      end
    else
      { error: parse_error(response) }
    end
  rescue StandardError => e
    Rails.logger.error("Plane projects error: #{e.message}")
    { error: e.message }
  end

  # Get project details with metadata (states, labels, members)
  def project_metadata(project_id)
    raise ArgumentError, 'Missing project ID' if project_id.blank?

    begin
      project = get_project(project_id)
      return { error: project[:error] } if project[:error]

      states = get_project_states(project_id)
      labels = get_project_labels(project_id)
      members = get_project_members(project_id)
      priorities = default_priorities

      {
        'project' => project,
        'states' => states.is_a?(Hash) && states[:error] ? [] : states,
        'labels' => labels.is_a?(Hash) && labels[:error] ? [] : labels,
        'members' => members.is_a?(Hash) && members[:error] ? [] : members,
        'priorities' => priorities
      }
    rescue StandardError => e
      Rails.logger.error("Plane project_metadata error: #{e.message}")
      { error: e.message }
    end
  end

  # Get single project
  def get_project(project_id)
    response = make_request(:get, "/api/v1/workspaces/#{@workspace_slug}/projects/#{project_id}/")
    
    if response.success?
      project = response.parsed_response
      {
        'id' => project['id'],
        'name' => project['name'],
        'identifier' => project['identifier'],
        'description' => project['description']
      }
    else
      { error: parse_error(response) }
    end
  rescue StandardError => e
    Rails.logger.error("Plane get_project error: #{e.message}")
    { error: e.message }
  end

  # Get project states (similar to Jira statuses)
  def get_project_states(project_id)
    response = make_request(:get, "/api/v1/workspaces/#{@workspace_slug}/projects/#{project_id}/states/")
    
    if response.success?
      data = response.parsed_response
      states_array = data.is_a?(Hash) ? data.fetch('results', []) : data
      states_array.map do |state|
        {
          'id' => state['id'],
          'name' => state['name'],
          'color' => state['color'],
          'group' => state['group'], # backlog, unstarted, started, completed, cancelled
          'sequence' => state['sequence']
        }
      end
    else
      { error: parse_error(response) }
    end
  rescue StandardError => e
    Rails.logger.error("Plane get_project_states error: #{e.message}")
    { error: e.message }
  end

  # Get project labels
  def get_project_labels(project_id)
    response = make_request(:get, "/api/v1/workspaces/#{@workspace_slug}/projects/#{project_id}/labels/")
    
    if response.success?
      data = response.parsed_response
      labels_array = data.is_a?(Hash) ? data.fetch('results', []) : data
      labels_array.map do |label|
        {
          'id' => label['id'],
          'name' => label['name'],
          'color' => label['color']
        }
      end
    else
      { error: parse_error(response) }
    end
  rescue StandardError => e
    Rails.logger.error("Plane get_project_labels error: #{e.message}")
    { error: e.message }
  end

  # Get project members
  def get_project_members(project_id)
    response = make_request(:get, "/api/v1/workspaces/#{@workspace_slug}/projects/#{project_id}/members/")
    
    if response.success?
      data = response.parsed_response
      members_array = data.is_a?(Hash) ? data.fetch('results', []) : data
      members_array.map do |member|
        {
          'id' => member.dig('member', 'id') || member['id'],
          'display_name' => member.dig('member', 'display_name') || member['display_name'],
          'email' => member.dig('member', 'email') || member['email'],
          'avatar' => member.dig('member', 'avatar') || member['avatar'],
          'role' => member['role']
        }
      end
    else
      { error: parse_error(response) }
    end
  rescue StandardError => e
    Rails.logger.error("Plane get_project_members error: #{e.message}")
    { error: e.message }
  end

  # Create a new issue
  def create_issue(params)
    validate_required_issue_params(params)

    begin
      issue_data = {
        'name' => params[:name] || params[:summary],
        'description_html' => params[:description] || '',
        'priority' => params[:priority] || 'none',
        'state' => params[:state_id],
        'labels' => params[:label_ids] || [],
        'assignees' => params[:assignee_ids] || []
      }

      # Add optional fields
      issue_data['parent'] = params[:parent_id] if params[:parent_id].present?
      issue_data['start_date'] = params[:start_date] if params[:start_date].present?
      issue_data['target_date'] = params[:target_date] if params[:target_date].present?
      issue_data['estimate_point'] = params[:estimate_point] if params[:estimate_point].present?

      Rails.logger.info("Plane: Creating issue with data: #{issue_data.to_json}")

      response = make_request(
        :post,
        "/api/v1/workspaces/#{@workspace_slug}/projects/#{params[:project_id]}/issues/",
        issue_data
      )

      Rails.logger.info("Plane: Create issue response code: #{response.code}")
      Rails.logger.info("Plane: Create issue response body: #{response.body}")

      if response.success?
        issue = response.parsed_response
        {
          'id' => issue['id'],
          'sequence_id' => issue['sequence_id'],
          'project_id' => issue['project'],
          'identifier' => "#{params[:project_identifier]}-#{issue['sequence_id']}",
          'name' => issue['name'],
          'state' => issue['state'],
          'priority' => issue['priority']
        }
      else
        { error: parse_error(response) }
      end
    rescue StandardError => e
      Rails.logger.error("Plane create_issue error: #{e.message}")
      Rails.logger.error("Plane create_issue backtrace: #{e.backtrace}")
      { error: e.message }
    end
  end

  # Get a specific issue by ID
  def get_issue(project_id, issue_id)
    raise ArgumentError, 'Missing project ID' if project_id.blank?
    raise ArgumentError, 'Missing issue ID' if issue_id.blank?

    begin
      response = make_request(:get, "/api/v1/workspaces/#{@workspace_slug}/projects/#{project_id}/issues/#{issue_id}/", nil, { expand: 'state_detail,assignee_details,label_details' })
      
      if response.success?
        issue = response.parsed_response
        format_issue(issue, project_id)
      else
        { error: parse_error(response) }
      end
    rescue StandardError => e
      Rails.logger.error("Plane get_issue error: #{e.message}")
      { error: e.message }
    end
  end

  # Search issues
  def search_issues(query, project_id = nil)
    raise ArgumentError, 'Missing search query' if query.blank?

    begin
      if project_id.present?
        # Search within a specific project
        params = { search: query, expand: 'state_detail' }
        endpoint = "/api/v1/workspaces/#{@workspace_slug}/projects/#{project_id}/issues/"
        response = make_request(:get, endpoint, nil, params)

        if response.success?
          data = response.parsed_response
          issues_array = data.is_a?(Hash) ? data.fetch('results', []) : data
          issues_array.map { |issue| format_issue(issue, project_id) }
        else
          { error: parse_error(response) }
        end
      else
        # Search across all projects by querying each project
        all_issues = []
        projects_response = projects
        if projects_response.is_a?(Hash) && (projects_response[:error] || projects_response['error'])
          return { error: projects_response[:error] || projects_response['error'] }
        end

        projects_list = projects_response.is_a?(Array) ? projects_response : (projects_response.is_a?(Hash) ? projects_response.fetch('results', []) : [])
        projects_list.each do |project|
          pid = project['id']
          params = { search: query, expand: 'state_detail' }
          endpoint = "/api/v1/workspaces/#{@workspace_slug}/projects/#{pid}/issues/"
          response = make_request(:get, endpoint, nil, params)
          next unless response.success?

          data = response.parsed_response
          issues_array = data.is_a?(Hash) ? data.fetch('results', []) : data
          all_issues.concat(issues_array.map { |issue| format_issue(issue, pid) })
        end
        all_issues
      end
    rescue StandardError => e
      Rails.logger.error("Plane search_issues error: #{e.message}")
      { error: e.message }
    end
  end

  # Update issue state (status)
  def update_issue_state(project_id, issue_id, state_id)
    update_issue(project_id, issue_id, { state: state_id })
  end

  # Update issue
  def update_issue(project_id, issue_id, params)
    raise ArgumentError, 'Missing project ID' if project_id.blank?
    raise ArgumentError, 'Missing issue ID' if issue_id.blank?

    begin
      response = make_request(
        :patch,
        "/api/v1/workspaces/#{@workspace_slug}/projects/#{project_id}/issues/#{issue_id}/",
        params
      )

      if response.success?
        issue = response.parsed_response
        format_issue(issue, project_id)
      else
        { error: parse_error(response) }
      end
    rescue StandardError => e
      Rails.logger.error("Plane update_issue error: #{e.message}")
      { error: e.message }
    end
  end

  # Add issue comment (called "issue activity" in Plane)
  def add_comment(project_id, issue_id, comment_body)
    raise ArgumentError, 'Missing project ID' if project_id.blank?
    raise ArgumentError, 'Missing issue ID' if issue_id.blank?
    raise ArgumentError, 'Missing comment body' if comment_body.blank?

    begin
      comment_data = {
        'comment_html' => comment_body
      }

      response = make_request(
        :post,
        "/api/v1/workspaces/#{@workspace_slug}/projects/#{project_id}/issues/#{issue_id}/comments/",
        comment_data
      )

      if response.success?
        comment = response.parsed_response
        actor_name = if comment['actor'].is_a?(Hash)
                       comment['actor']['display_name'] || 'Unknown'
                     else
                       'Unknown'
                     end
        {
          'id' => comment['id'],
          'comment_html' => comment['comment_html'],
          'actor' => actor_name,
          'created_at' => comment['created_at']
        }
      else
        { error: parse_error(response) }
      end
    rescue StandardError => e
      Rails.logger.error("Plane add_comment error: #{e.message}")
      { error: e.message }
    end
  end

  # Get issue comments
  def get_comments(project_id, issue_id)
    raise ArgumentError, 'Missing project ID' if project_id.blank?
    raise ArgumentError, 'Missing issue ID' if issue_id.blank?

    begin
      response = make_request(:get, "/api/v1/workspaces/#{@workspace_slug}/projects/#{project_id}/issues/#{issue_id}/comments/?expand=actor")

      if response.success?
        data = response.parsed_response
        comments_array = data.is_a?(Hash) ? data.fetch('results', []) : data
        comments_array.map do |comment|
          actor_name = if comment['actor'].is_a?(Hash)
                         comment['actor']['display_name'] || comment['actor']['first_name'] || 'Unknown'
                       else
                         'Unknown'
                       end
          {
            'id' => comment['id'],
            'comment_html' => comment['comment_html'],
            'actor' => actor_name,
            'created_at' => comment['created_at']
          }
        end
      else
        { error: parse_error(response) }
      end
    rescue StandardError => e
      Rails.logger.error("Plane get_comments error: #{e.message}")
      { error: e.message }
    end
  end

  # Link issue to a URL (using issue links)
  def link_issue(project_id, issue_id, url, title)
    raise ArgumentError, 'Missing project ID' if project_id.blank?
    raise ArgumentError, 'Missing issue ID' if issue_id.blank?

    begin
      link_data = {
        'url' => url,
        'title' => title || 'Chatwoot Conversation'
      }

      response = make_request(
        :post,
        "/api/v1/workspaces/#{@workspace_slug}/projects/#{project_id}/issues/#{issue_id}/links/",
        link_data
      )

      if response.success?
        link = response.parsed_response
        {
          'id' => link['id'],
          'url' => link['url'],
          'title' => link['title']
        }
      else
        { error: parse_error(response) }
      end
    rescue StandardError => e
      Rails.logger.error("Plane link_issue error: #{e.message}")
      { error: e.message }
    end
  end

  # Update issue labels
  def update_issue_labels(project_id, issue_id, label_ids)
    update_issue(project_id, issue_id, { labels: label_ids })
  end

  # Add attachment to issue
  def add_attachment(project_id, issue_id, file_path, filename = nil)
    raise ArgumentError, 'Missing project ID' if project_id.blank?
    raise ArgumentError, 'Missing issue ID' if issue_id.blank?
    raise ArgumentError, 'Missing file path' if file_path.blank?

    begin
      filename ||= File.basename(file_path)
      file_size = File.size(file_path)
      content_type = detect_content_type(file_path, filename)

      # Step 1: Create attachment record and get presigned upload URL
      Rails.logger.info("Plane add_attachment: Step 1 - Creating attachment record (name=#{filename}, type=#{content_type}, size=#{file_size})")
      create_response = make_request(
        :post,
        "/api/v1/workspaces/#{@workspace_slug}/projects/#{project_id}/issues/#{issue_id}/issue-attachments/",
        { name: filename, type: content_type, size: file_size }
      )

      unless create_response.success?
        error_msg = parse_error(create_response)
        Rails.logger.error("Plane add_attachment: Step 1 failed - #{error_msg}")
        return { error: error_msg }
      end

      create_data = create_response.parsed_response
      asset_id = create_data['asset_id']
      upload_data = create_data['upload_data']

      Rails.logger.info("Plane add_attachment: Step 1 success - asset_id=#{asset_id}")

      # Step 2: Upload file to presigned URL (S3/Minio)
      upload_url = upload_data['url']
      upload_fields = upload_data['fields'] || {}

      Rails.logger.info("Plane add_attachment: Step 2 - Uploading file to #{upload_url}")

      # Build multipart form data: fields first, then file last (S3 requirement)
      form_data = {}
      upload_fields.each { |key, value| form_data[key] = value }
      form_data['file'] = File.open(file_path)

      upload_response = HTTParty.post(
        upload_url,
        multipart: true,
        body: form_data,
        timeout: BASE_TIMEOUT * 3
      )

      # S3/Minio returns 204 No Content on successful upload
      unless [200, 201, 204].include?(upload_response.code)
        Rails.logger.error("Plane add_attachment: Step 2 failed - HTTP #{upload_response.code}: #{upload_response.body}")
        return { error: "File upload failed (HTTP #{upload_response.code})" }
      end

      Rails.logger.info("Plane add_attachment: Step 2 success - file uploaded")

      # Step 3: Confirm upload
      Rails.logger.info("Plane add_attachment: Step 3 - Confirming upload for asset #{asset_id}")
      confirm_response = make_request(
        :patch,
        "/api/v1/workspaces/#{@workspace_slug}/projects/#{project_id}/issues/#{issue_id}/issue-attachments/#{asset_id}/",
        { is_uploaded: true }
      )

      unless confirm_response.success? || confirm_response.code == 204
        Rails.logger.warn("Plane add_attachment: Step 3 confirm returned #{confirm_response.code} (non-fatal)")
      end

      Rails.logger.info("Plane add_attachment: Complete - attachment #{asset_id} created successfully")

      attachment_data = create_data['attachment'] || {}
      {
        'id' => asset_id,
        'name' => attachment_data['name'] || filename,
        'url' => create_data['asset_url'] || attachment_data['asset_url']
      }
    rescue StandardError => e
      Rails.logger.error("Plane add_attachment error: #{e.message}\n#{e.backtrace&.first(5)&.join("\n")}")
      { error: e.message }
    end
  end

  def detect_content_type(file_path, filename)
    ext = File.extname(filename).downcase
    mime_types = {
      '.pdf' => 'application/pdf',
      '.doc' => 'application/msword',
      '.docx' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      '.xls' => 'application/vnd.ms-excel',
      '.xlsx' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      '.ppt' => 'application/vnd.ms-powerpoint',
      '.pptx' => 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      '.txt' => 'text/plain',
      '.rtf' => 'application/rtf',
      '.png' => 'image/png',
      '.jpg' => 'image/jpeg',
      '.jpeg' => 'image/jpeg',
      '.gif' => 'image/gif',
      '.svg' => 'image/svg+xml',
      '.webp' => 'image/webp',
      '.mp4' => 'video/mp4',
      '.mp3' => 'audio/mpeg',
      '.wav' => 'audio/wav',
      '.zip' => 'application/zip',
      '.csv' => 'text/csv'
    }
    mime_types[ext] || 'application/octet-stream'
  end

  # Get issue activities (history)
  def get_issue_activities(project_id, issue_id)
    raise ArgumentError, 'Missing project ID' if project_id.blank?
    raise ArgumentError, 'Missing issue ID' if issue_id.blank?

    begin
      response = make_request(:get, "/api/v1/workspaces/#{@workspace_slug}/projects/#{project_id}/issues/#{issue_id}/activities/")

      if response.success?
        data = response.parsed_response
        activities_array = data.is_a?(Hash) ? data.fetch('results', []) : data
        activities_array.map do |activity|
          {
            'id' => activity['id'],
            'field' => activity['field'],
            'old_value' => activity['old_value'],
            'new_value' => activity['new_value'],
            'actor' => activity.dig('actor', 'display_name'),
            'created_at' => activity['created_at']
          }
        end
      else
        { error: parse_error(response) }
      end
    rescue StandardError => e
      Rails.logger.error("Plane get_issue_activities error: #{e.message}")
      { error: e.message }
    end
  end

  # Create a label
  def create_label(project_id, name, color = nil)
    raise ArgumentError, 'Missing project ID' if project_id.blank?
    raise ArgumentError, 'Missing label name' if name.blank?

    begin
      label_data = {
        'name' => name,
        'color' => color || generate_random_color
      }

      response = make_request(
        :post,
        "/api/v1/workspaces/#{@workspace_slug}/projects/#{project_id}/labels/",
        label_data
      )

      if response.success?
        label = response.parsed_response
        {
          'id' => label['id'],
          'name' => label['name'],
          'color' => label['color']
        }
      else
        { error: parse_error(response) }
      end
    rescue StandardError => e
      Rails.logger.error("Plane create_label error: #{e.message}")
      { error: e.message }
    end
  end

  private

  def normalize_base_url(url)
    return '' if url.blank?
    url.chomp('/')
  end

  def auth_headers
    {
      'Content-Type' => 'application/json',
      'Accept' => 'application/json',
      'X-API-Key' => @api_key
    }
  end

  def make_request(method, endpoint, body = nil, query_params = nil)
    url = "#{@base_url}#{endpoint}"
    
    options = {
      headers: auth_headers,
      timeout: BASE_TIMEOUT
    }

    options[:body] = body.to_json if body.present?
    options[:query] = query_params if query_params.present?

    Rails.logger.debug("Plane API #{method.upcase} #{url}")
    
    HTTParty.send(method, url, options)
  end

  def parse_error(response)
    if response.parsed_response.is_a?(Hash)
      response.parsed_response['detail'] ||
        response.parsed_response['error'] ||
        response.parsed_response['message'] ||
        "HTTP #{response.code}: #{response.message}"
    else
      "HTTP #{response.code}: #{response.message}"
    end
  end

  def format_issue(issue, project_id)
    {
      'id' => issue['id'],
      'sequence_id' => issue['sequence_id'],
      'project_id' => project_id,
      'name' => issue['name'],
      'description_html' => issue['description_html'],
      'priority' => issue['priority'],
      'state' => issue['state'],
      'state_detail' => issue['state_detail'],
      'assignees' => issue['assignees'] || [],
      'assignee_details' => issue['assignee_details'] || [],
      'labels' => issue['labels'] || [],
      'label_details' => issue['label_details'] || [],
      'created_at' => issue['created_at'],
      'updated_at' => issue['updated_at'],
      'target_date' => issue['target_date'],
      'start_date' => issue['start_date'],
      'parent' => issue['parent'],
      'sub_issues_count' => issue['sub_issues_count'] || 0
    }
  end

  def validate_required_issue_params(params)
    raise ArgumentError, 'Missing project ID' if params[:project_id].blank?
    raise ArgumentError, 'Missing issue name/summary' if params[:name].blank? && params[:summary].blank?
  end

  def default_priorities
    [
      { 'id' => 'urgent', 'name' => 'Urgent' },
      { 'id' => 'high', 'name' => 'High' },
      { 'id' => 'medium', 'name' => 'Medium' },
      { 'id' => 'low', 'name' => 'Low' },
      { 'id' => 'none', 'name' => 'None' }
    ]
  end

  def generate_random_color
    "##{SecureRandom.hex(3)}"
  end
end
