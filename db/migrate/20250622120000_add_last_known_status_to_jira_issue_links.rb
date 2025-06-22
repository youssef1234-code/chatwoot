class AddLastKnownStatusToJiraIssueLinks < ActiveRecord::Migration[7.0]
  def change
    add_column :jira_issue_links, :last_known_status, :string
    add_column :jira_issue_links, :last_status_check_at, :datetime
    add_column :jira_issue_links, :webhook_notifications_enabled, :boolean, default: true
    
    add_index :jira_issue_links, :last_status_check_at
    add_index :jira_issue_links, :webhook_notifications_enabled
  end
end
