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
    # Add agent information to the issue description
    enhanced_params = permitted_params.merge(
      description: enhanced_description_with_agent(permitted_params[:description] || ''),
      reporter_name: Current.user.name,
      reporter_email: Current.user.email
    )
    
    issue = jira_processor_service.create_issue(enhanced_params)
    if issue[:error]
      render json: { error: issue[:error] }, status: :unprocessable_entity
    else
      # Automatically link the created issue to the conversation
      issue_key = issue[:data][:key]
      link_result = jira_processor_service.link_issue(conversation_link, issue_key, "Created from Chatwoot by #{Current.user.name}")
      
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
    issue = jira_processor_service.link_issue(conversation_link, issue_key, title)
    if issue[:error]
      render json: { error: issue[:error] }, status: :unprocessable_entity
    else
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
    comment_id = permitted_params[:comment_id]
    issue = jira_processor_service.unlink_issue(issue_key, comment_id)

    if issue[:error]
      render json: { error: issue[:error] }, status: :unprocessable_entity
    else
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
    issues = jira_processor_service.linked_issues(conversation_link)

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

  def enhanced_description_with_agent(description)
    agent_info = "\n\n---\n*Created by:* #{Current.user.name} (#{Current.user.email})\n*Source:* Chatwoot - #{conversation_link}\n*Conversation ID:* #{@conversation.display_id}"
    
    if description.present?
      "#{description}#{agent_info}"
    else
      "Issue created from Chatwoot conversation#{agent_info}"
    end
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
end
