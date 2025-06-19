class AddCachedLabelsList < ActiveRecord::Migration[7.0]
  def change
    add_column :conversations, :cached_label_list, :string
    Conversation.reset_column_information
    
    # The cached label list will be populated automatically by the acts-as-taggable-on gem
    # when tags are accessed or saved on conversation records
  end
end
