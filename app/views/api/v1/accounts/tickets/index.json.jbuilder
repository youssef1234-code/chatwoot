json.array! @tickets do |ticket|
  json.id ticket.id
  json.title ticket.title
  json.description ticket.description
  json.status ticket.status
  json.priority ticket.priority
  json.category ticket.category
  json.resolved_at ticket.resolved_at
  json.created_at ticket.created_at
  json.updated_at ticket.updated_at
  json.jira_issue_key ticket.jira_issue_key
  json.jira_url ticket.jira_url
  json.jira_status ticket.jira_status
  json.jira_in_progress ticket.jira_in_progress?
  json.escalated_to_jira ticket.escalated_to_jira?
  json.duration_to_resolve ticket.duration_to_resolve

  json.conversation do
    json.id ticket.conversation.id
    json.display_id ticket.conversation.display_id
    json.status ticket.conversation.status
  end

  if ticket.contact
    json.contact do
      json.id ticket.contact.id
      json.name ticket.contact.name
      json.email ticket.contact.email
      json.phone_number ticket.contact.phone_number
      json.organization ticket.contact.additional_attributes&.dig('company_name') || ticket.contact.custom_attributes&.dig('organization') || ticket.contact.custom_attributes&.dig('company') || ticket.contact.additional_attributes&.dig('organization')
      json.additional_attributes ticket.contact.additional_attributes
      json.custom_attributes ticket.contact.custom_attributes
    end
  end

  json.created_by do
    json.id ticket.created_by.id
    json.name ticket.created_by.name
    json.email ticket.created_by.email
  end

  if ticket.assigned_agent
    json.assigned_agent do
      json.id ticket.assigned_agent.id
      json.name ticket.assigned_agent.name
      json.email ticket.assigned_agent.email
    end
  end

  json.message_count ticket.ticket_messages.count
  
  json.message_ids ticket.ticket_messages.pluck(:message_id)
end
