class CreatePlaneIssueLinks < ActiveRecord::Migration[7.1]
  def change
    create_table :plane_issue_links do |t|
      t.references :account, null: false, foreign_key: true
      t.references :conversation, null: false, foreign_key: true
      t.references :user, foreign_key: true
      t.string :project_id, null: false
      t.string :issue_id, null: false
      t.string :issue_key, null: false
      t.string :link_id
      t.datetime :linked_at, null: false
      t.string :last_known_state
      t.datetime :last_state_check_at
      t.boolean :webhook_notifications_enabled, default: true

      t.timestamps
    end

    add_index :plane_issue_links, :project_id
    add_index :plane_issue_links, :issue_id
    add_index :plane_issue_links, :issue_key
    add_index :plane_issue_links, [:conversation_id, :issue_id], unique: true
    add_index :plane_issue_links, :last_state_check_at
    add_index :plane_issue_links, :webhook_notifications_enabled
  end
end
