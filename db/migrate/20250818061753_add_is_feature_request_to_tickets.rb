class AddIsFeatureRequestToTickets < ActiveRecord::Migration[7.1]
  def change
    add_column :tickets, :is_feature_request, :boolean, default: false, null: false
    add_index :tickets, :is_feature_request
  end
end
