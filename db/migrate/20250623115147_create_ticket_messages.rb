class CreateTicketMessages < ActiveRecord::Migration[7.1]
  def change
    create_table :ticket_messages do |t|
      t.references :ticket, null: false, foreign_key: true, index: true
      t.references :message, null: false, foreign_key: true, index: true

      t.timestamps
    end

    add_index :ticket_messages, [:ticket_id, :message_id], unique: true
  end
end
