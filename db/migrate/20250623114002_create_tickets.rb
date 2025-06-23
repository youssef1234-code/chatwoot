class CreateTickets < ActiveRecord::Migration[7.1]
  def change
    create_table :tickets do |t|
      t.string :title, null: false
      t.text :description
      t.integer :status, default: 0, null: false
      t.integer :priority, default: 1, null: false
      t.string :issue_type
      t.datetime :resolved_at
      t.references :account, null: false, foreign_key: true, index: true
      t.references :conversation, null: false, foreign_key: true, index: true
      t.references :contact, null: true, foreign_key: true, index: true
      t.bigint :created_by_id, null: false
      t.bigint :assigned_agent_id, null: true
      t.string :jira_issue_key

      t.timestamps
    end

    add_foreign_key :tickets, :users, column: :created_by_id
    add_foreign_key :tickets, :users, column: :assigned_agent_id

    add_index :tickets, :created_by_id
    add_index :tickets, :assigned_agent_id
    add_index :tickets, :jira_issue_key
    add_index :tickets, :status
    add_index :tickets, :priority
  end
end
