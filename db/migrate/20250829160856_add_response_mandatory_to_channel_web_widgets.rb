class AddResponseMandatoryToChannelWebWidgets < ActiveRecord::Migration[7.1]
  def change
    add_column :channel_web_widgets, :response_mandatory, :boolean, default: false
  end
end
