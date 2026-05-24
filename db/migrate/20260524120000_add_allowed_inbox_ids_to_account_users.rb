class AddAllowedInboxIdsToAccountUsers < ActiveRecord::Migration[7.1]
  def change
    # Optional per-administrator channel (inbox) allow-list.
    # Empty => administrator sees all inboxes (default). Non-empty => restricted to those inboxes.
    add_column :account_users, :allowed_inbox_ids, :jsonb, default: [], null: false
  end
end
