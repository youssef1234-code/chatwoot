class AddStarAndPinToMessages < ActiveRecord::Migration[7.1]
  def change
    add_column :messages, :is_starred, :boolean, default: false, null: false
    add_column :messages, :is_pinned, :boolean, default: false, null: false
    add_column :messages, :starred_by, :bigint
    add_column :messages, :pinned_by, :bigint
    add_column :messages, :starred_at, :datetime
    add_column :messages, :pinned_at, :datetime
    
    add_index :messages, [:conversation_id, :is_starred], name: 'index_messages_on_conversation_starred'
    add_index :messages, [:conversation_id, :is_pinned], name: 'index_messages_on_conversation_pinned'
    add_index :messages, :starred_by
    add_index :messages, :pinned_by
    
    add_foreign_key :messages, :users, column: :starred_by
    add_foreign_key :messages, :users, column: :pinned_by
  end
end
