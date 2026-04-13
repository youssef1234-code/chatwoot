class Api::V1::Accounts::Integrations::PlaneController < Api::V1::Accounts::BaseController
  before_action :fetch_conversation, only: [:create_issue, :link_issue, :unlink_issue, :linked_issues]
  before_action :fetch_hook, only: [:destroy]

  def destroy
    @hook.destroy!
    # Invalidate cached Plane data for this account
    Rails.cache.delete_matched("plane/*/#{Current.account.id}*")
    head :ok
  end

  def webhook_secret_status
    hook = Current.account.hooks.find_by(app_id: 'plane')
    if hook
      has_secret = hook.settings&.dig('webhook_secret').present?
      render json: { configured: has_secret }, status: :ok
    else
      render json: { configured: false }, status: :ok
    end
  end

  def update_webhook_secret
    hook = Current.account.hooks.find_by(app_id: 'plane')
    unless hook
      render json: { error: 'Plane integration not configured' }, status: :unprocessable_entity
      return
    end

    secret = params[:webhook_secret].to_s.strip
    current_settings = hook.settings || {}

    if secret.blank?
      current_settings.delete('webhook_secret')
    else
      current_settings['webhook_secret'] = secret
    end

    hook.update!(settings: current_settings)
    render json: { configured: secret.present?, message: secret.present? ? 'Webhook secret saved' : 'Webhook secret removed' }, status: :ok
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def plane_settings
    hook = Current.account.hooks.find_by(app_id: 'plane')
    unless hook
      render json: { error: 'Plane integration not configured' }, status: :unprocessable_entity
      return
    end

    settings = hook.settings || {}
    render json: {
      done_statuses: settings['done_statuses'] || %w[Done Completed Closed Cancelled],
      status_colors: settings['status_colors'] || {},
      auto_resolve_conversation: settings.fetch('auto_resolve_conversation', true),
      mention_config: settings['mention_config'] || {
        'issue_creator' => true,
        'assignee' => true,
        'participating_agents' => true,
        'inbox_members' => false,
        'static_emails' => []
      }
    }, status: :ok
  end

  def update_plane_settings
    hook = Current.account.hooks.find_by(app_id: 'plane')
    unless hook
      render json: { error: 'Plane integration not configured' }, status: :unprocessable_entity
      return
    end

    current_settings = hook.settings || {}

    if params[:done_statuses].present?
      current_settings['done_statuses'] = Array(params[:done_statuses]).map(&:strip).reject(&:blank?)
    end

    if params.key?(:status_colors)
      current_settings['status_colors'] = params[:status_colors].to_unsafe_h rescue params[:status_colors]
    end

    if params.key?(:auto_resolve_conversation)
      current_settings['auto_resolve_conversation'] = ActiveModel::Type::Boolean.new.cast(params[:auto_resolve_conversation])
    end

    if params.key?(:mention_config)
      mc = params[:mention_config].to_unsafe_h rescue params[:mention_config]
      current_settings['mention_config'] = {
        'issue_creator' => ActiveModel::Type::Boolean.new.cast(mc['issue_creator']),
        'assignee' => ActiveModel::Type::Boolean.new.cast(mc['assignee']),
        'participating_agents' => ActiveModel::Type::Boolean.new.cast(mc['participating_agents']),
        'inbox_members' => ActiveModel::Type::Boolean.new.cast(mc['inbox_members']),
        'static_emails' => Array(mc['static_emails']).map { |e| e.to_s.strip.downcase }.reject(&:blank?)
      }
    end

    hook.update!(settings: current_settings)
    render json: {
      done_statuses: current_settings['done_statuses'] || [],
      status_colors: current_settings['status_colors'] || {},
      auto_resolve_conversation: current_settings.fetch('auto_resolve_conversation', true),
      mention_config: current_settings['mention_config'] || {},
      message: 'Settings updated successfully'
    }, status: :ok
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def plane_statuses
    project_id = params[:project_id]

    begin
      if project_id.present?
        states = plane_processor_service.send(:plane_client).get_project_states(project_id)
        if states.is_a?(Hash) && states[:error]
          render json: { error: states[:error] }, status: :unprocessable_entity
          return
        end

        formatted = states.map do |s|
          { id: s['id'], name: s['name'], color: s['color'], group: s['group'], sequence: s['sequence'], project_id: project_id }
        end
      else
        projects_result = plane_processor_service.projects
        if projects_result[:error]
          render json: { error: projects_result[:error] }, status: :unprocessable_entity
          return
        end

        all_states = []
        projects = projects_result[:data] || []
        projects = projects['results'] if projects.is_a?(Hash) && projects['results']

        Array(projects).each do |project|
          pid = project['id']
          states = plane_processor_service.send(:plane_client).get_project_states(pid)
          next if states.is_a?(Hash) && states[:error]

          states.each do |s|
            all_states << { id: s['id'], name: s['name'], color: s['color'], group: s['group'], sequence: s['sequence'],
                           project_id: pid, project_name: project['name'] }
          end
        end

        # Deduplicate by name, keep first occurrence
        seen = {}
        formatted = all_states.reject { |s| seen.key?(s[:name]) ? true : (seen[s[:name]] = true; false) }
      end

      render json: { states: formatted.sort_by { |s| s[:sequence] || 0 } }, status: :ok
    rescue StandardError => e
      Rails.logger.error("Plane: Failed to fetch statuses: #{e.message}")
      render json: { error: e.message }, status: :unprocessable_entity
    end
  end

  def test_connection
    begin
      # Test Plane connection and get user info
      plane_client = plane_processor_service.send(:plane_client)
      user_info = plane_client.current_user
      
      if user_info['error']
        render json: { 
          connected: false, 
          error: user_info['error'] 
        }, status: :unprocessable_entity
      else
        render json: { 
          connected: true, 
          user: user_info,
          message: "Successfully connected to Plane"
        }, status: :ok
      end
    rescue StandardError => e
      render json: { 
        connected: false, 
        error: e.message 
      }, status: :unprocessable_entity
    end
  end

  def projects
    projects = Rails.cache.fetch("plane/projects/#{Current.account.id}", expires_in: 10.minutes) do
      result = plane_processor_service.projects
      # Only cache successful results
      result[:error] ? nil : result[:data]
    end

    if projects.nil?
      # Cache miss or error — fetch fresh
      result = plane_processor_service.projects
      if result[:error]
        render json: { error: result[:error] }, status: :unprocessable_entity
      else
        render json: result[:data], status: :ok
      end
    else
      render json: projects, status: :ok
    end
  end

  def project_metadata
    project_id = permitted_params[:project_id]
    metadata = Rails.cache.fetch("plane/project_metadata/#{Current.account.id}/#{project_id}", expires_in: 30.minutes) do
      result = plane_processor_service.project_metadata(project_id)
      result[:error] ? nil : result[:data]
    end

    if metadata.nil?
      result = plane_processor_service.project_metadata(project_id)
      if result[:error]
        render json: { error: result[:error] }, status: :unprocessable_entity
      else
        render json: result[:data], status: :ok
      end
    else
      render json: metadata, status: :ok
    end
  end

  def create_issue
    # Combine user-provided labels 
    all_label_ids = []
    all_label_ids.concat(permitted_params[:label_ids]) if permitted_params[:label_ids].present?
    
    # Add a comment to the issue description with agent and org info
    enhanced_params = {
      project_id: permitted_params[:project_id],
      name: permitted_params[:summary] || permitted_params[:name],
      description: enhanced_description_with_agent_and_org(permitted_params[:description] || ''),
      state_id: permitted_params[:state_id],
      priority: permitted_params[:priority],
      assignee_ids: permitted_params[:assignee_ids],
      label_ids: all_label_ids.uniq.compact
    }
    
    Rails.logger.info("Plane: Creating issue with params: #{enhanced_params}")
    
    issue = plane_processor_service.create_issue(enhanced_params)
    if issue[:error]
      render json: { error: issue[:error] }, status: :unprocessable_entity
    else
      # Automatically link the created issue to the conversation
      issue_id = issue[:data][:id]
      project_id = permitted_params[:project_id]
      
      conversation_data = {
        conversation: @conversation,
        url: conversation_link
      }
      
      link_result = plane_processor_service.link_issue(
        conversation_data,
        project_id,
        issue_id,
        "Created from Chatwoot by #{Current.user.name}",
        user: Current.user
      )
      
      # Log activity even if linking fails
      Plane::ActivityMessageService.new(
        conversation: @conversation,
        action_type: :issue_created,
        issue_data: { 
          key: issue[:data][:key],
          url: issue[:data][:url],
          title: issue[:data][:title]
        },
        user: Current.user
      ).perform
      
      # Add organization labels to the created issue (resolve names to IDs)
      begin
        add_organization_labels_to_issue(project_id, issue_id)
      rescue StandardError => e
        Rails.logger.error("Plane: Failed to add organization labels to issue #{issue_id}: #{e.message}")
      end
      
      render json: issue[:data].merge(linked: !link_result[:error]), status: :ok
    end
  end

  def link_issue
    project_id = permitted_params[:project_id]
    issue_id = permitted_params[:issue_id]
    title = permitted_params[:title]
    
    conversation_data = {
      conversation: @conversation,
      url: conversation_link
    }
    
    issue = plane_processor_service.link_issue(
      conversation_data,
      project_id,
      issue_id,
      title,
      user: Current.user
    )
    
    if issue[:error]
      render json: { error: issue[:error] }, status: :unprocessable_entity
    else
      # Add organization labels to the issue when linking (asynchronously to avoid blocking)
      begin
        add_organization_labels_to_issue(project_id, issue_id)
      rescue StandardError => e
        Rails.logger.error("Plane: Failed to update organization labels for issue #{issue_id}: #{e.message}")
      end
      
      Plane::ActivityMessageService.new(
        conversation: @conversation,
        action_type: :issue_linked,
        issue_data: { key: issue[:data][:issue_key], project_id: project_id, issue_id: issue_id },
        user: Current.user
      ).perform
      render json: issue[:data], status: :ok
    end
  end

  def unlink_issue
    project_id = permitted_params[:project_id]
    issue_id = permitted_params[:issue_id]
    
    issue = plane_processor_service.unlink_issue(@conversation.id, project_id, issue_id)

    if issue[:error]
      render json: { error: issue[:error] }, status: :unprocessable_entity
    else
      Plane::ActivityMessageService.new(
        conversation: @conversation,
        action_type: :issue_unlinked,
        issue_data: { key: issue[:data][:issue_key], project_id: project_id, issue_id: issue_id },
        user: Current.user
      ).perform
      render json: issue[:data], status: :ok
    end
  end

  def linked_issues
    issues = plane_processor_service.linked_issues(@conversation.id)

    if issues[:error]
      render json: { error: issues[:error] }, status: :unprocessable_entity
    else
      render json: issues[:data], status: :ok
    end
  end

  def search_issues
    render json: { error: 'Specify search string with parameter q' }, status: :unprocessable_entity if params[:q].blank? && return

    query = params[:q]
    project_id = params[:project_id]
    issues = plane_processor_service.search_issues(query, project_id)
    if issues[:error]
      render json: { error: issues[:error] }, status: :unprocessable_entity
    else
      render json: issues[:data], status: :ok
    end
  end

  def get_issue
    project_id = permitted_params[:project_id]
    issue_id = permitted_params[:issue_id]
    issue = plane_processor_service.get_issue(project_id, issue_id)
    if issue[:error]
      render json: { error: issue[:error] }, status: :unprocessable_entity
    else
      render json: issue[:data], status: :ok
    end
  end

  def get_comments
    project_id = permitted_params[:project_id]
    issue_id = permitted_params[:issue_id]
    comments = plane_processor_service.get_comments(project_id, issue_id)
    if comments[:error]
      render json: { error: comments[:error] }, status: :unprocessable_entity
    else
      render json: comments[:data], status: :ok
    end
  end

  def add_comment
    project_id = permitted_params[:project_id]
    issue_id = permitted_params[:issue_id]
    comment_body = permitted_params[:comment_body]
    
    Rails.logger.info("Plane add_comment: project_id=#{project_id}, issue_id=#{issue_id}")
    
    if comment_body.blank?
      render json: { error: 'Comment body is required' }, status: :unprocessable_entity
      return
    end
    
    # Enhance comment with agent information
    enhanced_comment = enhanced_comment_with_agent(comment_body)
    
    comment = plane_processor_service.add_comment(project_id, issue_id, enhanced_comment)
    if comment[:error]
      render json: { error: comment[:error] }, status: :unprocessable_entity
    else
      render json: comment[:data], status: :ok
    end
  end

  def add_attachment
    project_id = permitted_params[:project_id]
    issue_id = permitted_params[:issue_id]
    uploaded_file = params[:file]
    
    Rails.logger.info("Plane add_attachment: project_id=#{project_id}, issue_id=#{issue_id}, file=#{uploaded_file&.original_filename}")
    
    if uploaded_file.blank?
      render json: { error: 'No file provided' }, status: :unprocessable_entity
      return
    end

    temp_path = nil
    begin
      # Save uploaded file temporarily with unique name
      unique_filename = "#{Time.current.to_i}_#{uploaded_file.original_filename}"
      temp_path = Rails.root.join('tmp', 'uploads', unique_filename)
      FileUtils.mkdir_p(File.dirname(temp_path))
      
      File.open(temp_path, 'wb') { |f| f.write(uploaded_file.read) }
      
      if !File.exist?(temp_path) || File.size(temp_path) == 0
        raise StandardError, "Failed to save uploaded file"
      end
      
      attachment = plane_processor_service.add_attachment(project_id, issue_id, temp_path, uploaded_file.original_filename)
      
      if attachment[:error]
        render json: { error: attachment[:error] }, status: :unprocessable_entity
      else
        render json: attachment[:data], status: :ok
      end
    rescue StandardError => e
      Rails.logger.error("Plane add_attachment error: #{e.message}")
      render json: { error: e.message }, status: :unprocessable_entity
    ensure
      if temp_path && File.exist?(temp_path)
        File.delete(temp_path)
      end
    end
  end

  def update_issue
    project_id = permitted_params[:project_id]
    issue_id = permitted_params[:issue_id]
    
    update_params = {}
    update_params[:name] = params[:name] if params[:name].present?
    update_params[:priority] = params[:priority] if params[:priority].present?
    update_params[:state] = params[:state_id] if params[:state_id].present?
    update_params[:assignees] = params[:assignee_ids] if params[:assignee_ids].present?
    update_params[:labels] = params[:label_ids] if params[:label_ids].present?
    
    if update_params.empty?
      render json: { error: 'No update parameters provided' }, status: :unprocessable_entity
      return
    end
    
    result = plane_processor_service.update_issue(project_id, issue_id, update_params)
    if result[:error]
      render json: { error: result[:error] }, status: :unprocessable_entity
    else
      render json: result[:data], status: :ok
    end
  rescue StandardError => e
    Rails.logger.error("Plane update_issue error: #{e.message}")
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def enhanced_description_with_agent_and_org(description)
    org_data = extract_organization_data
    
    agent_info = "\n\n---\n**Created by:** #{Current.user.name} (#{Current.user.email})\n**Source:** Chatwoot - #{conversation_link}\n**Conversation ID:** #{@conversation.display_id}"
    
    if org_data.present?
      agent_info += "\n**Organization(s):** #{org_data}"
    end
    
    if description.present?
      "#{description}#{agent_info}"
    else
      "Issue created from Chatwoot conversation#{agent_info}"
    end
  end

  def extract_organization_data
    return nil unless @conversation&.contact
    
    contact = @conversation.contact
    orgs = []
    
    if contact.custom_attributes.present?
      org_fields = ['organization', 'company', 'org', 'company_name', 'organisation', 'slug']
      
      org_fields.each do |field|
        if contact.custom_attributes[field].present?
          orgs << contact.custom_attributes[field]
        end
      end
    end
    
    if contact.additional_attributes.present?
      if contact.additional_attributes['company_name'].present?
        orgs << contact.additional_attributes['company_name']
      end
      if contact.additional_attributes['organization'].present?
        orgs << contact.additional_attributes['organization']
      end
    end
    
    return nil if orgs.empty?
    orgs.uniq.join(', ')
  end

  def enhanced_comment_with_agent(comment_body)
    agent_signature = "\n\n---\n**Comment by:** #{Current.user.name} (Chatwoot Agent)\n**Added via:** Chatwoot Integration"
    "#{comment_body}#{agent_signature}"
  end

  def conversation_link
    account_id = Current.account&.id || params[:account_id]
    "#{ENV.fetch('FRONTEND_URL', 'http://localhost:3000')}/app/accounts/#{account_id}/conversations/#{@conversation.display_id}"
  end

  def fetch_conversation
    @conversation = Current.account.conversations.find_by!(display_id: permitted_params[:conversation_id])
  end

  def plane_processor_service
    Integrations::Plane::ProcessorService.new(account: Current.account)
  end

  def permitted_params
    params.permit(:conversation_id, :project_id, :summary, :name, :description, :state_id, 
                  :priority, :issue_id, :title, :link_id, :comment_body, assignee_ids: [], label_ids: [])
  end

  def fetch_hook
    @hook = Current.account.hooks.find_by!(app_id: 'plane')
  end

  def extract_organization_labels
    return [] unless @conversation&.contact
    
    contact = @conversation.contact
    org_labels = []
    
    if contact.custom_attributes.present?
      org_fields = ['organization', 'company', 'org', 'company_name', 'organisation', 'slug']
      
      org_fields.each do |field|
        if contact.custom_attributes[field].present?
          label = sanitize_plane_label(contact.custom_attributes[field])
          org_labels << label if label.present?
        end
      end
    end
    
    if contact.additional_attributes.present?
      if contact.additional_attributes['company_name'].present?
        label = sanitize_plane_label(contact.additional_attributes['company_name'])
        org_labels << label if label.present?
      end
    end
    
    org_labels.uniq.compact
  end

  def sanitize_plane_label(label)
    return nil if label.blank?
    # Plane labels can have spaces and special characters, but let's keep it clean
    label.to_s.strip.gsub(/[^\w\s-]/, '').truncate(50)
  end

  def add_organization_labels_to_issue(project_id, issue_id)
    org_labels = extract_organization_labels
    return if org_labels.empty?
    
    # Get or create labels in the project
    existing_labels = plane_processor_service.send(:plane_client).get_project_labels(project_id)
    return if existing_labels.is_a?(Hash) && existing_labels[:error]
    
    label_ids = []
    
    org_labels.each do |label_name|
      existing_label = existing_labels.find { |l| l['name'].downcase == label_name.downcase }
      
      if existing_label
        label_ids << existing_label['id']
      else
        # Create new label
        new_label = plane_processor_service.send(:plane_client).create_label(project_id, label_name)
        label_ids << new_label['id'] if new_label && !new_label[:error]
      end
    end
    
    # Update issue with labels
    if label_ids.any?
      plane_processor_service.update_issue_labels(project_id, issue_id, label_ids)
    end
  end
end
