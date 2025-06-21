class CreateJiraIssueLinks < ActiveRecord::Migration[7.1]
  def change
    create_table :jira_issue_links do |t|
      t.references :conversation, null: false, foreign_key: true
      t.string :issue_key, null: false
      t.string :comment_id
      t.datetime :linked_at, null: false
      t.references :account, null: false, foreign_key: true
      t.references :user, null: true, foreign_key: true # User who created the link

      t.timestamps
    end

    # Add indexes for efficient querying
    add_index :jira_issue_links, %i[conversation_id issue_key], unique: true
    add_index :jira_issue_links, :issue_key
  end
end
