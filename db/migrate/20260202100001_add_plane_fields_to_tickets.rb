class AddPlaneFieldsToTickets < ActiveRecord::Migration[7.1]
  def change
    add_column :tickets, :plane_issue_id, :string
    add_column :tickets, :plane_issue_key, :string
    add_column :tickets, :plane_project_id, :string
    add_column :tickets, :plane_state, :string
    add_column :tickets, :plane_in_progress, :boolean

    add_index :tickets, :plane_issue_id
    add_index :tickets, :plane_issue_key
    add_index :tickets, :plane_project_id
  end
end
