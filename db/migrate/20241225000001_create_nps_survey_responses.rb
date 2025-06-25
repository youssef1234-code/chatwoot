class CreateNpsSurveyResponses < ActiveRecord::Migration[6.1]
  def change
    create_table :nps_survey_responses do |t|
      t.integer :rating, null: false
      t.text :feedback_message
      t.references :account, null: false, foreign_key: true, index: true
      t.references :contact, null: false, foreign_key: true, index: true
      t.references :conversation, null: false, foreign_key: true, index: true
      t.references :message, null: false, foreign_key: true, index: { unique: true }
      t.references :assigned_agent, null: true, foreign_key: { to_table: :users }, index: true

      t.timestamps
    end

    add_index :nps_survey_responses, [:contact_id, :created_at]
    add_index :nps_survey_responses, [:account_id, :created_at]
  end
end
