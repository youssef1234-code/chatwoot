class CreateJiraOnboardingStatuses < ActiveRecord::Migration[7.1]
  def change
    create_table :jira_onboarding_statuses do |t|
      t.references :account, null: false, foreign_key: true
      t.string :organization_name, null: false
      t.string :onboarding_key
      t.string :onboarding_status
      t.string :onboarding_summary
      t.string :current_session
      t.string :contact_email
      t.string :onboarding_url
      t.string :stage
      t.integer :sessions_total, default: 0
      t.integer :sessions_done, default: 0
      t.integer :sessions_in_progress, default: 0
      t.integer :tasks_total, default: 0
      t.integer :tasks_done, default: 0
      t.integer :overall_percent, default: 0
      t.jsonb :sessions_data, default: []
      t.jsonb :raw_response, default: {}
      t.datetime :last_fetched_at

      t.timestamps
    end

    add_index :jira_onboarding_statuses, [:account_id, :organization_name], unique: true, name: 'idx_jira_onboarding_on_account_org'
    add_index :jira_onboarding_statuses, :organization_name
    add_index :jira_onboarding_statuses, :onboarding_key
    add_index :jira_onboarding_statuses, :last_fetched_at
  end
end
