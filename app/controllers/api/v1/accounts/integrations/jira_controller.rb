class Api::V1::Accounts::Integrations::JiraController < Api::V1::Accounts::BaseController
  before_action :fetch_conversation, only: [:create_issue, :link_issue, :unlink_issue, :linked_issues]
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
    all_labels.concat(permitted_params[:labels]) if permitted_params[:labels].present?
    all_labels.concat(org_labels)
    all_labels << 'chatwoot' # Add a Chatwoot label to identify issues created from Chatwoot
    
    # Add agent information and organization data to the issue description
    enhanced_params = permitted_params.merge(
      description: enhanced_description_with_agent_and_org(permitted_params[:description] || ''),
      reporter_name: Current.user.name,
      reporter_email: Current.user.email,
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
        user: Current.user
      )
      
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
      user: Current.user
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
    # comment_id is no longer needed since we're using database-backed linking
    issue = jira_processor_service.unlink_issue(@conversation.id, issue_key)

    if issue[:error]
      render json: { error: issue[:error] }, status: :unprocessable_entity
    else
      # Update organization labels after unlinking (remove labels if no more conversations from those companies)
      begin
        add_organization_labels_to_issue(issue_key)
      rescue StandardError => e
        Rails.logger.error("JIRA: Failed to update organization labels after unlinking issue #{issue_key}: #{e.message}")
        # Continue with the response even if label update fails
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
      render json: issues[:data], status: :ok
    end
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
    agent_info = "\n\n---\n*Created by:* #{Current.user.name} (#{Current.user.email})\n*Source:* Chatwoot - #{conversation_link}\n*Conversation ID:* #{@conversation.display_id}"
    
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
    agent_signature = "\n\n---\n*Comment by:* #{Current.user.name} (Chatwoot Agent)\n*Added via:* Chatwoot Integration"
    "#{comment_body}#{agent_signature}"
  end

  def conversation_link
    account_id = Current.account&.id || params[:account_id]
    "#{ENV.fetch('FRONTEND_URL', 'http://localhost:3000')}/app/accounts/#{account_id}/conversations/#{@conversation.display_id}"
  end

  def fetch_conversation
    @conversation = Current.account.conversations.find_by!(display_id: permitted_params[:conversation_id])
  end

  def jira_processor_service
    Integrations::Jira::ProcessorService.new(account: Current.account)
  end

  def permitted_params
    params.permit(:conversation_id, :project_key, :summary, :description, :issue_type_id, 
                  :assignee_id, :priority_id, :issue_key, :title, :comment_id, :comment_body, labels: [])
  end

  def fetch_hook
    @hook = Current.account.hooks.find_by!(app_id: 'jira')
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
    
    # JIRA labels must be alphanumeric with no spaces
    # Convert to lowercase, replace spaces/special chars with underscores, limit length
    sanitized = text.to_s
                   .downcase
                   .gsub(/[^a-z0-9_-]/, '_')  # Replace non-alphanumeric chars with underscore
                   .gsub(/_+/, '_')           # Replace multiple underscores with single
                   .gsub(/^_+|_+$/, '')       # Remove leading/trailing underscores
                   .slice(0, 50)              # Limit to 50 characters
    
    # Ensure it doesn't start with a number (JIRA requirement)
    sanitized = "org_#{sanitized}" if sanitized.match?(/^\d/)
    
    sanitized.present? ? sanitized : nil
  end

  # Add method to update labels on an existing JIRA issue
  def add_organization_labels_to_issue(issue_key)
    Rails.logger.info("JIRA: Starting to add organization labels to issue #{issue_key}")
    
    # Get all organizations from ALL conversations linked to this issue
    all_org_labels = get_all_organization_labels_for_issue(issue_key)
    Rails.logger.info("JIRA: All organization labels for issue #{issue_key}: #{all_org_labels}")
    
    return if all_org_labels.empty?

    # Add Chatwoot label as well
    labels_to_add = all_org_labels + ['chatwoot']
    
    Rails.logger.info("JIRA: Adding organization labels to issue #{issue_key}: #{labels_to_add}")
    
    begin
      # Get current issue to retrieve existing labels
      current_issue = jira_processor_service.get_issue(issue_key)
      if current_issue.is_a?(Hash) && (current_issue[:error] || current_issue['error'])
        Rails.logger.warn("JIRA: Could not retrieve issue #{issue_key} to add labels: #{current_issue[:error] || current_issue['error']}")
        return
      end
      
      # Get existing labels from the issue (labels are in data.labels)
      existing_labels = current_issue.dig(:data, :labels) || []
      # JIRA labels can be strings or objects with 'name' property
      existing_labels = existing_labels.map { |label| label.is_a?(Hash) ? label['name'] : label }.compact
      Rails.logger.info("JIRA: Issue #{issue_key} existing labels: #{existing_labels}")
      
      # Combine existing labels with all organization labels, removing duplicates
      all_labels = (existing_labels + labels_to_add).uniq.compact
      Rails.logger.info("JIRA: Final labels for issue #{issue_key}: #{all_labels}")
      
      # Update the issue with the new labels
      update_result = jira_processor_service.update_issue_labels(issue_key, all_labels)
      if update_result[:error]
        Rails.logger.warn("JIRA: Could not add labels to issue #{issue_key}: #{update_result[:error]}")
      else
        Rails.logger.info("JIRA: Successfully updated labels for issue #{issue_key}")
      end
    rescue StandardError => e
      Rails.logger.error("JIRA: Error adding labels to issue #{issue_key}: #{e.message}")
      Rails.logger.error("JIRA: Error backtrace: #{e.backtrace}")
    end
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
