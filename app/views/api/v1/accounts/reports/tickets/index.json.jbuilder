json.tickets @tickets do |ticket|
  json.id ticket.id
  json.title ticket.title
  json.description ticket.description
  json.status ticket.status
  json.priority ticket.priority
  json.category ticket.category
  json.escalated_to_jira ticket.escalated_to_jira?
  json.jira_issue_key ticket.jira_issue_key
  json.jira_in_progress ticket.jira_in_progress?
  json.duration_to_resolve do
    if ticket.resolved_at && ticket.created_at
      (ticket.resolved_at - ticket.created_at).to_i
    else
      nil
    end
  end
  json.assigned_agent do
    if ticket.assigned_agent
      json.id ticket.assigned_agent.id
      json.name ticket.assigned_agent.name
      json.email ticket.assigned_agent.email
      json.avatar_url ticket.assigned_agent.avatar_url
    end
  end
  json.created_by do
    if ticket.created_by
      json.id ticket.created_by.id
      json.name ticket.created_by.name
      json.email ticket.created_by.email
    end
  end
  json.conversation do
    if ticket.conversation
      json.id ticket.conversation.id
      json.display_id ticket.conversation.display_id
    end
  end
  json.created_at ticket.created_at.to_i
  json.updated_at ticket.updated_at.to_i
  json.resolved_at ticket.resolved_at&.to_i
end

json.metrics @metrics
