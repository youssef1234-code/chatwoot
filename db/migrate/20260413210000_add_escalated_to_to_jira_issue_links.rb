class AddEscalatedToToJiraIssueLinks < ActiveRecord::Migration[7.0]
  def change
    add_column :jira_issue_links, :escalated_to, :string
    add_column :jira_issue_links, :escalated_from, :string
  end
end
