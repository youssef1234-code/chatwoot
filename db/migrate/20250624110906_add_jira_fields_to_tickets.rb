class AddJiraFieldsToTickets < ActiveRecord::Migration[7.1]
  def change
    add_column :tickets, :jira_status, :string
    add_column :tickets, :jira_in_progress, :boolean
  end
end
