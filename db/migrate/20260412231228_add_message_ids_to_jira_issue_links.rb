class AddMessageIdsToJiraIssueLinks < ActiveRecord::Migration[7.1]
  def change
    add_column :jira_issue_links, :message_ids, :jsonb, default: []
  end
end
