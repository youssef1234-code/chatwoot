class Api::V1::Accounts::Integrations::JiraController < Api::V1::Accounts::BaseController
  before_action :fetch_conversation, only: [:create_issue, :link_issue, :unlink_issue, :linked_issues, :issue_messages, :upload_message_attachments]
  before_action :fetch_conversation_if_present, only: [:escalate_issue]
  before_action :fetch_hook, only: [:destroy]

  def destroy
    @hook.destroy!
    head :ok
  end

  def test_connection
    begin
      # Test JIRA connection and get user info
      jira_client = jira_processor_service.send(:jira_client)
      user_info = jira_client.current_user
      
      if user_info['error']
        render json: { 
          connected: false, 
          error: user_info['error'] 
        }, status: :unprocessable_entity
      else
        render json: { 
          connected: true, 
          user: user_info,
          message: "Successfully connected to JIRA"
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
    projects = jira_processor_service.projects
    if projects[:error]
      render json: { error: projects[:error] }, status: :unprocessable_entity
    else
      render json: projects[:data], status: :ok
    end
  end

  def project_metadata
    project_key = permitted_params[:project_key]
    metadata = jira_processor_service.project_metadata(project_key)
    if metadata[:error]
      render json: { error: metadata[:error] }, status: :unprocessable_entity
    else
      render json: metadata[:data], status: :ok
    end
  end

  def create_issue
    # Extract organization labels
    org_labels = extract_organization_labels
    
    # Combine user-provided labels with organization labels
    all_labels = []
    if permitted_params[:labels].present?
      all_labels.concat(permitted_params[:labels].map { |l| sanitize_jira_label(l) })
    end
    all_labels.concat(org_labels)
    all_labels << 'chatwoot'
    all_labels << channel_type_label
    
    # Use configured 1st line project if set and no project_key provided
    project_key = permitted_params[:project_key].presence || jira_processor_service.first_line_project_key
    
    # Add agent information and organization data to the issue description
    # reporter_email: the user creating the issue (they have a JIRA account).
    # For auto-created tickets (no Current.user), admin_email falls back to the
    # integration's configured email so the issue is still created under a known JIRA user.
    enhanced_params = permitted_params.merge(
      project_key: project_key,
      description: enhanced_description_with_agent_and_org(permitted_params[:description] || ''),
      reporter_name: Current.user&.name,
      reporter_email: Current.user&.email,
      admin_email: jira_integration_admin_email,
      labels: all_labels.uniq.compact # Remove duplicates and nil values
    )
    
    Rails.logger.info("JIRA: Creating issue with labels: #{enhanced_params[:labels]}")
    
    issue = jira_processor_service.create_issue(enhanced_params)
    if issue[:error]
      render json: { error: issue[:error] }, status: :unprocessable_entity
    else
      # Automatically link the created issue to the conversation
      issue_key = issue[:data][:key]
      
      conversation_data = {
        conversation: @conversation,
        url: conversation_link
      }
      
      link_result = jira_processor_service.link_issue(
        conversation_data, 
        issue_key, 
        "Created from Chatwoot by #{Current.user.name}",
        user: Current.user,
        message_ids: params[:message_ids] || []
      )
      
      # Handle Service Desk customers instead of just labels
      handle_service_desk_customers(issue_key)
      
      # Log activity even if linking fails
      Jira::ActivityMessageService.new(
        conversation: @conversation,
        action_type: :issue_created,
        issue_data: { 
          key: issue_key,
          url: issue[:data][:url],
          title: issue[:data][:title]
        },
        user: Current.user
      ).perform
      
      render json: issue[:data].merge(linked: !link_result[:error]), status: :ok
    end
  end

  def link_issue
    issue_key = permitted_params[:issue_key]
    title = permitted_params[:title]
    
    conversation_data = {
      conversation: @conversation,
      url: conversation_link
    }
    
    issue = jira_processor_service.link_issue(
      conversation_data, 
      issue_key, 
      title,
      user: Current.user,
      message_ids: params[:message_ids] || []
    )
    
    if issue[:error]
      render json: { error: issue[:error] }, status: :unprocessable_entity
    else
      # Add organization labels to the issue when linking (asynchronously to avoid blocking)
      # This ensures the linking succeeds even if label updating fails
      begin
        add_organization_labels_to_issue(issue_key)
      rescue StandardError => e
        Rails.logger.error("JIRA: Failed to update organization labels for issue #{issue_key}: #{e.message}")
        # Continue with the response even if label update fails
      end
      
      # Also add Service Desk customers when linking (multi-org support)
      begin
        handle_service_desk_customers(issue_key)
      rescue StandardError => e
        Rails.logger.error("JIRA: Failed to add customers when linking issue #{issue_key}: #{e.message}")
      end
      
      Jira::ActivityMessageService.new(
        conversation: @conversation,
        action_type: :issue_linked,
        issue_data: { key: issue_key },
        user: Current.user
      ).perform
      render json: issue[:data], status: :ok
    end
  end

  def unlink_issue
    issue_key = permitted_params[:issue_key]

    # Capture org labels from THIS conversation BEFORE deleting the link,
    # so we can identify which labels to remove from the JIRA issue.
    org_labels_being_removed = collect_all_known_org_labels

    # Delete the database link
    issue = jira_processor_service.unlink_issue(@conversation.id, issue_key)

    if issue[:error]
      render json: { error: issue[:error] }, status: :unprocessable_entity
    else
      # Sync labels: remove stale org labels, keep labels from still-linked conversations
      begin
        sync_organization_labels_on_unlink(issue_key, org_labels_being_removed)
      rescue StandardError => e
        Rails.logger.error("JIRA: Failed to sync org labels after unlinking issue #{issue_key}: #{e.message}")
      end

      # Remove Service Desk organizations that no longer have linked conversations
      begin
        remove_stale_service_desk_organizations(issue_key, org_labels_being_removed)
      rescue StandardError => e
        Rails.logger.error("JIRA: Failed to remove SD orgs after unlinking issue #{issue_key}: #{e.message}")
      end

      Jira::ActivityMessageService.new(
        conversation: @conversation,
        action_type: :issue_unlinked,
        issue_data: { key: issue_key },
        user: Current.user
      ).perform
      render json: issue[:data], status: :ok
    end
  end

  def linked_issues
    issues = jira_processor_service.linked_issues(@conversation.id)

    if issues[:error]
      render json: { error: issues[:error] }, status: :unprocessable_entity
    else
      render json: {
        issues: issues[:data],
        second_line_project_key: issues[:second_line_project_key]
      }, status: :ok
    end
  end

  def issue_messages
    issue_key = params[:issue_key]
    return render json: { error: 'issue_key is required' }, status: :bad_request if issue_key.blank?

    link = JiraIssueLink.find_by(
      account: Current.account,
      issue_key: issue_key,
      conversation_id: @conversation.id
    )
    return render json: { error: 'Issue not linked to this conversation' }, status: :not_found unless link

    message_ids = link.message_ids || []
    return render json: [], status: :ok if message_ids.empty?

    messages = @conversation.messages.where(id: message_ids).order(:created_at).map do |msg|
      {
        id: msg.id,
        content: msg.content,
        message_type: msg.message_type,
        created_at: msg.created_at.iso8601,
        sender_name: msg.sender&.name || 'Unknown',
        attachments: msg.attachments.map { |a| { file_type: a.file_type, data_url: a.file_url } }
      }
    end

    render json: messages, status: :ok
  end

  def search_issue
    render json: { error: 'Specify search string with parameter q' }, status: :unprocessable_entity if params[:q].blank? && return

    query = params[:q]
    issues = jira_processor_service.search_issue(query)
    if issues[:error]
      render json: { error: issues[:error] }, status: :unprocessable_entity
    else
      render json: issues[:data], status: :ok
    end
  end

  def get_issue
    issue_key = permitted_params[:issue_key]
    issue = jira_processor_service.get_issue(issue_key)
    if issue[:error]
      render json: { error: issue[:error] }, status: :unprocessable_entity
    else
      render json: issue[:data], status: :ok
    end
  end

  def get_comments
    issue_key = permitted_params[:issue_key]
    comments = jira_processor_service.get_comments(issue_key)
    if comments[:error]
      render json: { error: comments[:error] }, status: :unprocessable_entity
    else
      render json: comments[:data], status: :ok
    end
  end

  def add_comment
    issue_key = permitted_params[:issue_key]
    comment_body = permitted_params[:comment_body]
    
    Rails.logger.info("JIRA add_comment: issue_key=#{issue_key}")
    Rails.logger.info("JIRA add_comment: original comment_body=#{comment_body.inspect}")
    
    if comment_body.blank?
      render json: { error: 'Comment body is required' }, status: :unprocessable_entity
      return
    end
    
    # Enhance comment with agent information
    enhanced_comment = enhanced_comment_with_agent(comment_body)
    Rails.logger.info("JIRA add_comment: enhanced_comment=#{enhanced_comment.inspect}")
    
    comment = jira_processor_service.add_comment(issue_key, enhanced_comment)
    if comment[:error]
      render json: { error: comment[:error] }, status: :unprocessable_entity
    else
      render json: comment[:data], status: :ok
    end
  end

  def add_attachment
    issue_key = permitted_params[:issue_key]
    uploaded_file = params[:file]
    
    Rails.logger.info("JIRA add_attachment: issue_key=#{issue_key}, file=#{uploaded_file&.original_filename}")
    
    if uploaded_file.blank?
      render json: { error: 'No file provided' }, status: :unprocessable_entity
      return
    end

    temp_path = nil
    begin
      # Save uploaded file temporarily with unique name to avoid conflicts
      unique_filename = "#{Time.current.to_i}_#{uploaded_file.original_filename}"
      temp_path = Rails.root.join('tmp', 'uploads', unique_filename)
      FileUtils.mkdir_p(File.dirname(temp_path))
      
      Rails.logger.info("JIRA: Saving uploaded file to: #{temp_path}")
      File.open(temp_path, 'wb') { |f| f.write(uploaded_file.read) }
      
      if !File.exist?(temp_path) || File.size(temp_path) == 0
        raise StandardError, "Failed to save uploaded file"
      end
      
      Rails.logger.info("JIRA: File saved successfully, size: #{File.size(temp_path)} bytes")
      
      attachment = jira_processor_service.add_attachment(issue_key, temp_path, uploaded_file.original_filename)
      
      if attachment[:error]
        Rails.logger.error("JIRA: Attachment upload failed: #{attachment[:error]}")
        render json: { error: attachment[:error] }, status: :unprocessable_entity
      else
        Rails.logger.info("JIRA: Attachment uploaded successfully: #{attachment[:data]}")
        render json: attachment[:data], status: :ok
      end
    rescue StandardError => e
      Rails.logger.error("JIRA add_attachment error: #{e.message}")
      Rails.logger.error("JIRA add_attachment backtrace: #{e.backtrace}")
      render json: { error: e.message }, status: :unprocessable_entity
    ensure
      # Always clean up temp file
      if temp_path && File.exist?(temp_path)
        File.delete(temp_path)
        Rails.logger.info("JIRA: Cleaned up temp file: #{temp_path}")
      end
    end
  end

  # Upload non-audio attachments from selected messages to a JIRA issue
  def upload_message_attachments
    issue_key = params[:issue_key]
    message_ids = params[:message_ids] || []

    return render json: { error: 'issue_key is required' }, status: :bad_request if issue_key.blank?
    return render json: { error: 'message_ids is required' }, status: :bad_request if message_ids.empty?

    messages = @conversation.messages.where(id: message_ids).includes(:attachments)
    uploaded = []
    errors = []

    messages.each do |msg|
      msg.attachments.each do |attachment|
        # Skip audio/voice attachments
        next if attachment.file_type == 'audio'

        temp_path = nil
        begin
          blob = attachment.file.blob
          next unless blob

          filename = blob.filename.to_s
          temp_path = Rails.root.join('tmp', 'uploads', "#{Time.current.to_i}_#{SecureRandom.hex(4)}_#{filename}")
          FileUtils.mkdir_p(File.dirname(temp_path))

          # Download from ActiveStorage to temp file
          File.open(temp_path, 'wb') do |f|
            blob.download { |chunk| f.write(chunk) }
          end

          next if !File.exist?(temp_path) || File.size(temp_path).zero?

          result = jira_processor_service.add_attachment(issue_key, temp_path.to_s, filename)
          if result[:error]
            errors << { filename: filename, error: result[:error] }
          else
            uploaded << { filename: filename }
          end
        rescue StandardError => e
          Rails.logger.error("JIRA: Failed to upload attachment #{attachment.id}: #{e.message}")
          errors << { filename: attachment.file.blob&.filename.to_s, error: e.message }
        ensure
          File.delete(temp_path) if temp_path && File.exist?(temp_path)
        end
      end
    end

    render json: { uploaded: uploaded, errors: errors }, status: :ok
  end

  # Escalate a JIRA issue from 1st line to 2nd line project
  def escalate_issue
    issue_key = permitted_params[:issue_key]
    target_project = permitted_params[:target_project_key]
    target_issue_type_id = permitted_params[:target_issue_type_id]

    # Check if already escalated
    original_link = JiraIssueLink.find_by(
      conversation_id: @conversation&.id,
      issue_key: issue_key
    )
    if original_link&.escalated_to.present?
      render json: { error: "Issue #{issue_key} has already been escalated to #{original_link.escalated_to}" }, status: :unprocessable_entity
      return
    end

    # Prevent escalating issues that are already in the 2nd line project
    second_line_key = jira_processor_service.second_line_project_key
    issue_project = issue_key.split('-').first
    if second_line_key.present? && issue_project == second_line_key
      render json: { error: "Issue #{issue_key} is already in the 2nd line project (#{second_line_key})" }, status: :unprocessable_entity
      return
    end

    # Pass the escalating user's email so JIRA reporter is set on the new issue
    result = jira_processor_service.escalate_issue(
      issue_key, target_project, target_issue_type_id,
      reporter_email: Current.user&.email
    )

    if result[:error]
      render json: { error: result[:error] }, status: :unprocessable_entity
    else
      escalation_data = result[:data]
      new_key = escalation_data[:new_issue_key]
      target = escalation_data[:target_project]

      # Link the new 2nd line issue to the same conversation
      if @conversation && new_key
        conversation_data = {
          conversation: @conversation,
          url: conversation_link
        }

        jira_processor_service.link_issue(
          conversation_data,
          new_key,
          "Escalated from #{issue_key} by #{Current.user&.name}",
          user: Current.user,
          message_ids: original_link&.message_ids || []
        )

        # Mark the new link as escalated_from the original
        new_link = JiraIssueLink.find_by(conversation_id: @conversation.id, issue_key: new_key)
        new_link&.update!(escalated_from: issue_key)

        # Mark the original link as escalated_to the new issue
        original_link&.update!(escalated_to: new_key)
      end

      # Log activity in conversation if available
      if @conversation
        Jira::ActivityMessageService.new(
          conversation: @conversation,
          action_type: :issue_escalated,
          issue_data: { key: issue_key, new_key: new_key, target_project: target },
          user: Current.user
        ).perform
      end

      render json: escalation_data.merge(message: "Issue #{issue_key} escalated → new issue #{new_key} created in #{target}"), status: :ok
    end
  end

  # Get JIRA integration settings (project keys, statuses, etc.)
  def get_settings
    hook = Current.account.hooks.find_by(app_id: 'jira')
    return render json: { error: 'JIRA integration not configured' }, status: :not_found unless hook

    settings = hook.settings
    render json: {
      site_url: settings['site_url'],
      email: settings['email'],
      first_line_project_key: settings['first_line_project_key'],
      second_line_project_key: settings['second_line_project_key'],
      final_statuses: jira_processor_service.final_statuses,
      deployment_type: settings['deployment_type'] || 'data_center',
      service_desk_enabled: settings['service_desk_enabled'] != false,
      status_color_mapping: settings['status_color_mapping'] || {}
    }, status: :ok
  end

  # Get all available JIRA statuses (for dropdown selection)
  def get_statuses
    result = jira_processor_service.statuses
    if result[:error]
      render json: { error: result[:error] }, status: :unprocessable_entity
    else
      render json: result[:data], status: :ok
    end
  end

  # Update JIRA integration settings (project keys, statuses, etc.)
  def update_settings
    hook = Current.account.hooks.find_by(app_id: 'jira')
    return render json: { error: 'JIRA integration not configured' }, status: :not_found unless hook

    settings_params = params.permit(
      :site_url, :api_token, :deployment_type, :email,
      :first_line_project_key, :second_line_project_key, :service_desk_enabled,
      final_statuses: [],
      status_color_mapping: {}
    )

    # Reject blank values so empty fields don't overwrite existing settings
    merged = settings_params.to_h.reject { |_k, v| v.nil? || (v.is_a?(String) && v.blank?) }
    # Always strip trailing slashes from site_url
    merged['site_url'] = merged['site_url'].chomp('/') if merged['site_url'].present?

    # Deep-merge status_color_mapping so individual color changes are preserved
    if merged['status_color_mapping'].is_a?(Hash)
      existing_colors = hook.settings['status_color_mapping'] || {}
      merged['status_color_mapping'] = existing_colors.merge(merged['status_color_mapping'])
    end

    new_settings = hook.settings.merge(merged)

    hook.update!(settings: new_settings)
    render json: { message: 'Settings updated successfully', settings: new_settings.except('api_token') }, status: :ok
  end

  # Transcribe audio attachments on-demand for AI ticket generation
  def transcribe_audio
    message_ids = params[:message_ids]
    return render json: { error: 'No message IDs provided' }, status: :bad_request if message_ids.blank?

    openai_hook = Current.account.hooks.find_by(app_id: 'openai')
    api_key = openai_hook&.settings&.dig('api_key')
    api_key = InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_API_KEY')&.value if api_key.blank?
    return render json: { error: 'OpenAI API key not configured' }, status: :unprocessable_entity if api_key.blank?

    transcriptions = {}
    messages = Current.account.messages.where(id: message_ids).includes(:attachments)

    messages.each do |message|
      message.attachments.where(file_type: :audio).each do |attachment|
        # Skip if already transcribed
        existing = attachment.meta&.dig('transcribed_text')
        if existing.present?
          transcriptions[attachment.id] = existing
          next
        end

        # Download and transcribe
        begin
          temp_dir = Rails.root.join('tmp/uploads')
          FileUtils.mkdir_p(temp_dir)
          temp_path = File.join(temp_dir, "transcribe_#{attachment.id}_#{attachment.file.filename}")
          File.write(temp_path, attachment.file.download, mode: 'wb')

          client = OpenAI::Client.new(access_token: api_key, log_errors: Rails.env.development?)
          response = client.audio.transcribe(
            parameters: {
              model: 'gpt-4o-mini-transcribe',
              file: File.open(temp_path),
            }
          )

          FileUtils.rm_f(temp_path)

          text = response['text']
          if text.present?
            attachment.update!(meta: (attachment.meta || {}).merge('transcribed_text' => text))
            transcriptions[attachment.id] = text
          end
        rescue StandardError => e
          Rails.logger.error("Audio transcription error for attachment #{attachment.id}: #{e.message}")
        end
      end
    end

    render json: { transcriptions: transcriptions }, status: :ok
  end

  private

  def enhanced_description_with_agent_and_org(description)
    # Get organization data from conversation contact
    org_data = extract_organization_data
    
    agent_info = "\n\n---\n*Created by:* #{Current.user.name} (#{Current.user.email})\n*Source:* Chatwoot - #{conversation_link}\n*Conversation ID:* #{@conversation.display_id}"
    
    if org_data.present?
      agent_info += "\n*Organization(s):* #{org_data}"
    end
    
    if description.present?
      "#{description}#{agent_info}"
    else
      "Issue created from Chatwoot conversation#{agent_info}"
    end
  end

  def enhanced_description_with_agent(description)
    creator_name = Current.user&.name || 'System (Auto-created)'
    creator_email = Current.user&.email || jira_integration_admin_email
    agent_info = "\n\n---\n*Created by:* #{creator_name} (#{creator_email})\n*Source:* Chatwoot - #{conversation_link}\n*Conversation ID:* #{@conversation.display_id}"
    
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
    
    # Check contact's custom attributes for organization data
    if contact.custom_attributes.present?
      # Common organization field names to check
      org_fields = ['organization', 'company', 'org', 'company_name', 'organisation', 'slug']
      
      org_fields.each do |field|
        if contact.custom_attributes[field].present?
          orgs << contact.custom_attributes[field]
        end
      end
    end
    
    # Also check additional attributes
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
    commenter_name = Current.user&.name || 'System'
    agent_signature = "\n\n---\n*Comment by:* #{commenter_name} (Chatwoot Agent)\n*Added via:* Chatwoot Integration"
    "#{comment_body}#{agent_signature}"
  end

  def conversation_link
    account_id = Current.account&.id || params[:account_id]
    "#{ENV.fetch('FRONTEND_URL', 'http://localhost:3000')}/app/accounts/#{account_id}/conversations/#{@conversation.display_id}"
  end

  def channel_type_label
    return 'support_chat' unless @conversation&.inbox

    inbox = @conversation.inbox
    inbox_name = inbox.name.to_s.downcase

    if inbox_name.include?('whatsapp') && inbox_name.include?('group')
      'whatsapp_group'
    elsif inbox.channel_type == 'Channel::Whatsapp' || inbox_name.include?('whatsapp')
      'whatsapp'
    elsif inbox.channel_type == 'Channel::WebWidget'
      'support_chat'
    elsif inbox.channel_type == 'Channel::Email'
      'email'
    else
      sanitize_jira_label(inbox.name) || 'support_chat'
    end
  end

  def fetch_conversation
    @conversation = Current.account.conversations.find_by!(display_id: permitted_params[:conversation_id])
  end

  def fetch_conversation_if_present
    @conversation = Current.account.conversations.find_by(display_id: permitted_params[:conversation_id]) if permitted_params[:conversation_id].present?
  end

  def jira_processor_service
    Integrations::Jira::ProcessorService.new(account: Current.account)
  end

  def permitted_params
    params.permit(:conversation_id, :project_key, :summary, :description, :issue_type_id, 
                  :assignee_id, :priority_id, :issue_key, :title, :comment_id, :comment_body,
                  :target_project_key, :target_issue_type_id, labels: [], message_ids: [])
  end

  def fetch_hook
    @hook = Current.account.hooks.find_by!(app_id: 'jira')
  end

  # Fallback email for auto-created tickets when no Current.user is present.
  # Uses the JIRA integration's configured email (the admin/service account).
  def jira_integration_admin_email
    hook = Current.account&.hooks&.find_by(app_id: 'jira')
    hook&.settings&.dig('email') || hook&.settings&.dig('username')
  end

  # Handle Service Desk customer creation and linking instead of using labels
  def handle_service_desk_customers(issue_key)
    return unless jira_processor_service.service_desk_enabled?
    return unless @conversation&.contact

    contact = @conversation.contact
    org_names = extract_organization_names

    # Handle JIRA Service Management organizations
    handle_service_desk_organizations(issue_key, org_names)

    if org_names.present?
      org_names.each do |org_name|
        # Try to find/create the customer in JIRA using org email or contact info
        org_email = extract_org_email(org_name)
        next if org_email.blank?

        begin
          customer_result = jira_processor_service.find_or_create_customer(org_email, org_name)
          if customer_result[:data]
            customer_id = customer_result[:data]['accountId'] || customer_result[:data]['name'] || customer_result[:data]['key']
            if customer_id
              jira_processor_service.add_customer_to_issue(issue_key, customer_id)
              Rails.logger.info("JIRA: Added customer #{org_name} (#{customer_id}) to issue #{issue_key}")
            end
          end
        rescue StandardError => e
          Rails.logger.error("JIRA: Failed to add customer #{org_name} to issue #{issue_key}: #{e.message}")
        end
      end
    else
      # Use contact email/name as customer if no org present
      contact_email = contact.email
      contact_name = contact.name
      if contact_email.present?
        begin
          customer_result = jira_processor_service.find_or_create_customer(contact_email, contact_name)
          if customer_result[:data]
            customer_id = customer_result[:data]['accountId'] || customer_result[:data]['name'] || customer_result[:data]['key']
            if customer_id
              jira_processor_service.add_customer_to_issue(issue_key, customer_id)
              Rails.logger.info("JIRA: Added contact #{contact_name} (#{customer_id}) as customer to issue #{issue_key}")
            end
          end
        rescue StandardError => e
          Rails.logger.error("JIRA: Failed to add contact as customer to issue #{issue_key}: #{e.message}")
        end
      end
    end
  rescue StandardError => e
    Rails.logger.error("JIRA: handle_service_desk_customers error for issue #{issue_key}: #{e.message}")
  end

  # Create/find JIRA SM organizations and link them to the issue
  def handle_service_desk_organizations(issue_key, org_names)
    return if org_names.blank?

    # Determine the project key from the issue
    project_key = issue_key.split('-').first

    org_names.each do |org_name|
      begin
        # Find or create the organization in JIRA Service Management
        org_result = jira_processor_service.find_or_create_organization(org_name)
        next unless org_result[:data]

        org_id = org_result[:data]['id']
        next unless org_id

        Rails.logger.info("JIRA: Found/created organization '#{org_name}' with ID #{org_id}")

        # Add organization to the project's service desk
        jira_processor_service.add_organization_to_project_service_desk(project_key, org_id)

        # Add organization to the issue/request
        jira_processor_service.add_organization_to_issue(issue_key, org_id)

        Rails.logger.info("JIRA: Linked organization '#{org_name}' (#{org_id}) to issue #{issue_key}")
      rescue StandardError => e
        Rails.logger.error("JIRA: Failed to handle organization '#{org_name}' for issue #{issue_key}: #{e.message}")
      end
    end
  end

  # Extract organization names (not sanitized for labels)
  def extract_organization_names
    return [] unless @conversation&.contact

    contact = @conversation.contact
    org_names = []

    if contact.custom_attributes.present?
      org_fields = ['organization', 'company', 'org', 'company_name', 'organisation']
      org_fields.each do |field|
        org_names << contact.custom_attributes[field] if contact.custom_attributes[field].present?
      end
    end

    if contact.additional_attributes.present?
      org_names << contact.additional_attributes['company_name'] if contact.additional_attributes['company_name'].present?
      org_names << contact.additional_attributes['organization'] if contact.additional_attributes['organization'].present?
    end

    org_names.uniq.compact
  end

  # Try to derive an org email from contact or custom attributes
  def extract_org_email(org_name)
    return nil if org_name.blank?

    contact = @conversation&.contact
    return nil unless contact

    # If the contact has an email, use it (the contact represents the customer/org)
    return contact.email if contact.email.present?

    # Try to find email in custom attributes
    if contact.custom_attributes.present?
      email_fields = ['email', 'customer_email', 'org_email', 'company_email']
      email_fields.each do |field|
        return contact.custom_attributes[field] if contact.custom_attributes[field].present?
      end
    end

    nil
  end

  def extract_organization_labels
    return [] unless @conversation&.contact
    
    contact = @conversation.contact
    org_labels = []
    
    # Check contact's custom attributes for organization data
    if contact.custom_attributes.present?
      # Common organization field names to check
      org_fields = ['organization', 'company', 'org', 'company_name', 'organisation', 'slug']
      
      org_fields.each do |field|
        if contact.custom_attributes[field].present?
          # Convert organization name to a valid JIRA label format
          # JIRA labels can't have spaces, special characters, etc.
          label = sanitize_jira_label(contact.custom_attributes[field])
          org_labels << label if label.present?
        end
      end
    end
    
    # Also check additional attributes
    if contact.additional_attributes.present?
      if contact.additional_attributes['company_name'].present?
        label = sanitize_jira_label(contact.additional_attributes['company_name'])
        org_labels << label if label.present?
      end
      if contact.additional_attributes['organization'].present?
        label = sanitize_jira_label(contact.additional_attributes['organization'])
        org_labels << label if label.present?
      end
    end
    
    # Remove duplicates and return
    org_labels.uniq.compact
  end

  def sanitize_jira_label(text)
    return nil if text.blank?
    
    # JIRA labels support Unicode but cannot contain spaces
    # Replace spaces with underscores, strip only control/whitespace chars, limit length
    sanitized = text.to_s
                   .strip
                   .gsub(/\s+/, '_')             # Replace whitespace with underscore
                   .gsub(/[,;=|&\\\/]/, '_')     # Replace JIRA-problematic chars with underscore
                   .gsub(/_+/, '_')              # Replace multiple underscores with single
                   .gsub(/^_+|_+$/, '')          # Remove leading/trailing underscores
                   .slice(0, 50)                 # Limit to 50 characters
    
    sanitized.present? ? sanitized : nil
  end

  # Sync organization labels on a JIRA issue based on currently linked conversations.
  # Called on link AND unlink — adds labels for linked orgs, removes labels for unlinked orgs.
  def add_organization_labels_to_issue(issue_key)
    Rails.logger.info("JIRA: Syncing organization labels for issue #{issue_key}")

    begin
      # Get current issue to retrieve existing labels
      current_issue = jira_processor_service.get_issue(issue_key)
      if current_issue.is_a?(Hash) && (current_issue[:error] || current_issue['error'])
        Rails.logger.warn("JIRA: Could not retrieve issue #{issue_key} to sync labels: #{current_issue[:error] || current_issue['error']}")
        return
      end

      existing_labels = current_issue.dig(:data, :labels) || []
      existing_labels = existing_labels.map { |label| label.is_a?(Hash) ? label['name'] : label }.compact
      Rails.logger.info("JIRA: Issue #{issue_key} existing labels: #{existing_labels}")

      # Collect ALL possible org labels from the conversation being unlinked
      # (still available via @conversation since we fetch it before unlinking the DB record)
      all_possible_org_labels = collect_all_known_org_labels
      Rails.logger.info("JIRA: All possible org labels (superset): #{all_possible_org_labels}")

      # Get org labels that SHOULD still be on the issue (from remaining linked conversations)
      current_org_labels = get_all_organization_labels_for_issue(issue_key)
      Rails.logger.info("JIRA: Org labels from still-linked conversations: #{current_org_labels}")

      # Stale = labels that look like org labels but no linked conversation backs them anymore
      stale_org_labels = all_possible_org_labels - current_org_labels
      Rails.logger.info("JIRA: Stale org labels to remove: #{stale_org_labels}")

      # Build final label set: keep non-org labels intact, add current org labels, remove stale ones
      final_labels = existing_labels.reject { |l| stale_org_labels.include?(l) }
      final_labels = (final_labels + current_org_labels + ['chatwoot']).uniq.compact

      # Remove 'chatwoot' label only if zero conversations remain linked
      remaining_links = JiraIssueLink.for_issue(issue_key).where(account: Current.account).count
      final_labels.delete('chatwoot') if remaining_links.zero?

      Rails.logger.info("JIRA: Final labels for issue #{issue_key}: #{final_labels}")

      update_result = jira_processor_service.update_issue_labels(issue_key, final_labels)
      if update_result[:error]
        Rails.logger.warn("JIRA: Could not sync labels on issue #{issue_key}: #{update_result[:error]}")
      else
        Rails.logger.info("JIRA: Successfully synced labels for issue #{issue_key}")
      end
    rescue StandardError => e
      Rails.logger.error("JIRA: Error syncing labels on issue #{issue_key}: #{e.message}")
      Rails.logger.error("JIRA: Error backtrace: #{e.backtrace&.first(5)}")
    end
  end

  # Collect org labels from the current @conversation's contact (used to identify stale labels)
  def collect_all_known_org_labels
    labels = []
    return labels unless @conversation&.contact

    contact = @conversation.contact

    if contact.custom_attributes.present?
      org_fields = ['organization', 'company', 'org', 'company_name', 'organisation', 'slug']
      org_fields.each do |field|
        if contact.custom_attributes[field].present?
          label = sanitize_jira_label(contact.custom_attributes[field])
          labels << label if label.present?
        end
      end
    end

    if contact.additional_attributes.present?
      %w[company_name organization].each do |field|
        if contact.additional_attributes[field].present?
          label = sanitize_jira_label(contact.additional_attributes[field])
          labels << label if label.present?
        end
      end
    end

    labels.uniq.compact
  end

  # Sync JIRA issue labels after unlinking: remove org labels that are no longer backed by any linked conversation
  def sync_organization_labels_on_unlink(issue_key, removed_org_labels)
    Rails.logger.info("JIRA: Syncing labels on unlink for issue #{issue_key}, removed org labels: #{removed_org_labels}")

    begin
      current_issue = jira_processor_service.get_issue(issue_key)
      if current_issue.is_a?(Hash) && (current_issue[:error] || current_issue['error'])
        Rails.logger.warn("JIRA: Could not retrieve issue #{issue_key} to sync labels")
        return
      end

      existing_labels = current_issue.dig(:data, :labels) || []
      existing_labels = existing_labels.map { |l| l.is_a?(Hash) ? l['name'] : l }.compact

      # Org labels still valid from remaining linked conversations
      still_valid_org_labels = get_all_organization_labels_for_issue(issue_key)

      # Labels to remove: were from the unlinked conversation but NOT from any remaining conversation
      labels_to_remove = removed_org_labels - still_valid_org_labels
      Rails.logger.info("JIRA: Labels to remove from issue #{issue_key}: #{labels_to_remove}")

      final_labels = existing_labels.reject { |l| labels_to_remove.include?(l) }

      # Also remove 'chatwoot' if no conversations remain linked
      remaining_links = JiraIssueLink.for_issue(issue_key).where(account: Current.account).count
      if remaining_links.zero?
        final_labels.delete('chatwoot')
        # Remove channel_type labels too
        final_labels.reject! { |l| l.start_with?('channel_') }
      end

      if final_labels.sort != existing_labels.sort
        Rails.logger.info("JIRA: Updating labels for issue #{issue_key}: #{existing_labels} -> #{final_labels}")
        update_result = jira_processor_service.update_issue_labels(issue_key, final_labels)
        Rails.logger.warn("JIRA: Label update failed: #{update_result[:error]}") if update_result[:error]
      else
        Rails.logger.info("JIRA: No label changes needed for issue #{issue_key}")
      end
    rescue StandardError => e
      Rails.logger.error("JIRA: Error syncing labels on unlink for #{issue_key}: #{e.message}")
    end
  end

  # Remove Service Desk organizations from a JIRA issue when conversations are unlinked
  def remove_stale_service_desk_organizations(issue_key, removed_org_labels)
    return unless jira_processor_service.service_desk_enabled?

    # Get org NAMES (unsanitized) from the conversation being unlinked
    unlinked_org_names = extract_organization_names

    # Get org names still valid from remaining linked conversations
    still_valid_org_names = get_remaining_organization_names(issue_key)

    # Orgs to remove: from unlinked conversation but NOT from any remaining conversation
    orgs_to_remove = unlinked_org_names - still_valid_org_names
    return if orgs_to_remove.blank?

    Rails.logger.info("JIRA: Removing Service Desk orgs from issue #{issue_key}: #{orgs_to_remove}")

    orgs_to_remove.each do |org_name|
      begin
        org_result = jira_processor_service.find_or_create_organization(org_name)
        next unless org_result[:data]

        org_id = org_result[:data]['id']
        next unless org_id

        jira_processor_service.remove_organization_from_issue(issue_key, org_id)
        Rails.logger.info("JIRA: Removed organization '#{org_name}' (#{org_id}) from issue #{issue_key}")
      rescue StandardError => e
        Rails.logger.error("JIRA: Failed to remove org '#{org_name}' from issue #{issue_key}: #{e.message}")
      end
    end
  end

  # Get unsanitized org names from remaining linked conversations (for SD org comparison)
  def get_remaining_organization_names(issue_key)
    org_names = []

    JiraIssueLink.for_issue(issue_key)
                 .includes(conversation: :contact)
                 .where(account: Current.account)
                 .each do |link|
      contact = link.conversation&.contact
      next unless contact

      if contact.custom_attributes.present?
        %w[organization company org company_name organisation].each do |field|
          org_names << contact.custom_attributes[field] if contact.custom_attributes[field].present?
        end
      end

      if contact.additional_attributes.present?
        %w[company_name organization].each do |field|
          org_names << contact.additional_attributes[field] if contact.additional_attributes[field].present?
        end
      end
    end

    org_names.uniq.compact
  end

  # Get organization labels from all conversations linked to this JIRA issue
  def get_all_organization_labels_for_issue(issue_key)
    all_org_labels = []
    
    # Find all conversations linked to this JIRA issue
    linked_conversations = JiraIssueLink.for_issue(issue_key)
                                       .includes(conversation: :contact)
                                       .where(account: Current.account)
    
    Rails.logger.info("JIRA: Found #{linked_conversations.count} conversations linked to issue #{issue_key}")
    
    linked_conversations.each do |link|
      conversation = link.conversation
      next unless conversation&.contact
      
      Rails.logger.debug("JIRA: Processing conversation #{conversation.id} for issue #{issue_key}")
      
      # Extract organization labels for this conversation's contact
      contact = conversation.contact
      org_labels_for_contact = []
      
      # Check custom attributes
      if contact.custom_attributes.present?
        org_fields = ['organization', 'company', 'org', 'company_name', 'organisation', 'slug']
        org_fields.each do |field|
          if contact.custom_attributes[field].present?
            label = sanitize_jira_label(contact.custom_attributes[field])
            if label.present?
              org_labels_for_contact << label
              Rails.logger.debug("JIRA: Found org label '#{label}' from custom_attributes.#{field} for contact #{contact.id}")
            end
          end
        end
      end
      
      # Check additional attributes
      if contact.additional_attributes.present?
        if contact.additional_attributes['company_name'].present?
          label = sanitize_jira_label(contact.additional_attributes['company_name'])
          if label.present?
            org_labels_for_contact << label
            Rails.logger.debug("JIRA: Found org label '#{label}' from additional_attributes.company_name for contact #{contact.id}")
          end
        end
        if contact.additional_attributes['organization'].present?
          label = sanitize_jira_label(contact.additional_attributes['organization'])
          if label.present?
            org_labels_for_contact << label
            Rails.logger.debug("JIRA: Found org label '#{label}' from additional_attributes.organization for contact #{contact.id}")
          end
        end
      end
      
      # Check if contact name itself could be an organization
      if contact.name.present? && org_labels_for_contact.empty?
        potential_org = contact.name.strip
      
        # If name is in format: customerName(companyName), extract and use companyName directly
        if potential_org =~ /\(([^)]+)\)/
          potential_org = $1.strip
        else
          # Only check further if no (companyName) format
          if potential_org.match?(/\b(ltd|llc|inc|corp|company|group|enterprises|solutions|technologies|systems|services)\b/i) ||
             potential_org.length > 30 ||
             !potential_org.match?(/\A[A-Z][a-z]+ [A-Z][a-z]+\z/) # Not a "First Last" format
            # keep as-is
          else
            potential_org = nil # Not considered an org
          end
        end
      
        if potential_org.present?
          label = sanitize_jira_label(potential_org)
          if label.present?
            org_labels_for_contact << label
            Rails.logger.debug("JIRA: Found org label '#{label}' from contact name for contact #{contact.id}")
          end
        end
      end
      all_org_labels.concat(org_labels_for_contact)
      Rails.logger.debug("JIRA: Contact #{contact.id} contributed labels: #{org_labels_for_contact}")
    end
    
    final_labels = all_org_labels.uniq.compact
    Rails.logger.info("JIRA: Final organization labels for issue #{issue_key}: #{final_labels}")
    final_labels
  end
end
