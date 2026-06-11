class Jira::ServiceDeskAssociationJob < ApplicationJob
  queue_as :low

  # Associates the conversation's affected client with a freshly created/linked/escalated
  # JIRA Service Management issue as an organization + customer.
  #
  # Runs async on purpose: find_or_create_organization paginates the ENTIRE JSM org list
  # (50 per page, O(N) API calls). Once that list grew large (the bulk migration created
  # hundreds of orgs) the scan blew past the 15s request timeout — which 500'd
  # create_issue/link/escalate AND left issues with no organization. Off the request path
  # there is no rack timeout, so it completes reliably.
  def perform(account_id:, conversation_id:, issue_key:)
    return if issue_key.blank?

    @account = Account.find_by(id: account_id)
    @conversation = @account&.conversations&.find_by(id: conversation_id)
    return unless @account && @conversation

    handle_service_desk_customers(issue_key)
  end

  private

  def jira_processor_service
    @jira_processor_service ||= Integrations::Jira::ProcessorService.new(account: @account)
  end

  def handle_service_desk_customers(issue_key)
    return unless jira_processor_service.service_desk_enabled?
    return unless @conversation&.contact

    contact = @conversation.contact
    org_names = extract_organization_names

    handle_service_desk_organizations(issue_key, org_names)

    if org_names.present?
      org_names.each do |org_name|
        org_email = extract_org_email(org_name)
        next if org_email.blank?

        add_customer(issue_key, org_email, org_name)
      end
    elsif contact.email.present?
      add_customer(issue_key, contact.email, contact.name)
    end
  rescue StandardError => e
    Rails.logger.error("JIRA: ServiceDeskAssociation error for issue #{issue_key}: #{e.message}")
  end

  def add_customer(issue_key, email, name)
    customer_result = jira_processor_service.find_or_create_customer(email, name)
    return unless customer_result[:data]

    customer_id = customer_result[:data]['accountId'] || customer_result[:data]['name'] || customer_result[:data]['key']
    return unless customer_id

    jira_processor_service.add_customer_to_issue(issue_key, customer_id)
    Rails.logger.info("JIRA: Added customer #{name} (#{customer_id}) to issue #{issue_key}")
  rescue StandardError => e
    Rails.logger.error("JIRA: Failed to add customer #{name} to issue #{issue_key}: #{e.message}")
  end

  def handle_service_desk_organizations(issue_key, org_names)
    return if org_names.blank?

    project_key = issue_key.split('-').first

    org_names.each do |org_name|
      org_result = jira_processor_service.find_or_create_organization(org_name)
      next unless org_result[:data]

      org_id = org_result[:data]['id']
      next unless org_id

      jira_processor_service.add_organization_to_project_service_desk(project_key, org_id)
      jira_processor_service.add_organization_to_issue(issue_key, org_id)
      Rails.logger.info("JIRA: Linked organization '#{org_name}' (#{org_id}) to issue #{issue_key}")
    rescue StandardError => e
      Rails.logger.error("JIRA: Failed to handle organization '#{org_name}' for issue #{issue_key}: #{e.message}")
    end
  end

  def extract_organization_names
    return [] unless @conversation&.contact

    contact = @conversation.contact
    org_names = []

    if contact.custom_attributes.present?
      ['organization', 'company', 'org', 'company_name', 'organisation'].each do |field|
        org_names << contact.custom_attributes[field] if contact.custom_attributes[field].present?
      end
    end

    if contact.additional_attributes.present?
      org_names << contact.additional_attributes['company_name'] if contact.additional_attributes['company_name'].present?
      org_names << contact.additional_attributes['organization'] if contact.additional_attributes['organization'].present?
    end

    org_names.uniq.compact
  end

  def extract_org_email(org_name)
    return nil if org_name.blank?

    contact = @conversation&.contact
    return nil unless contact
    return contact.email if contact.email.present?

    if contact.custom_attributes.present?
      ['email', 'customer_email', 'org_email', 'company_email'].each do |field|
        return contact.custom_attributes[field] if contact.custom_attributes[field].present?
      end
    end

    nil
  end
end
