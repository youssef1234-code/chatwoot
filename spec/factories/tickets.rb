# frozen_string_literal: true

FactoryBot.define do
  factory :ticket do
    title { 'Sample Ticket' }
    description { 'This is a sample ticket description' }
    status { 'open' }
    priority { 'medium' }
    category { 'Support' }
    is_feature_request { false }
    
    association :account
    association :conversation
    association :created_by, factory: :user
    
    trait :with_assigned_agent do
      association :assigned_agent, factory: :user
    end
    
    trait :feature_request do
      is_feature_request { true }
      category { 'Feature Request' }
    end
    
    trait :resolved do
      status { 'resolved' }
      resolved_at { 2.hours.ago }
    end
    
    trait :escalated do
      status { 'escalated' }
      jira_issue_key { 'PROJ-123' }
    end
    
    trait :high_priority do
      priority { 'high' }
    end
    
    trait :urgent_priority do
      priority { 'urgent' }
    end
  end
end
