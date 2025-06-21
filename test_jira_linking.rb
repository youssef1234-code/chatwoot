#!/usr/bin/env ruby

# Test script to verify JIRA label aggregation when same issue is linked to multiple conversations

require_relative 'config/environment'

# Helper method to create a conversation with a contact from a specific company
def create_conversation_with_company(account, company_name)
  contact = FactoryBot.create(:contact, 
    account: account, 
    custom_attributes: { 'company' => company_name }
  )
  FactoryBot.create(:conversation, account: account, contact: contact)
end

# Test scenario
puts "=== JIRA Label Aggregation Test ==="

# Create test account
account = FactoryBot.create(:account)

# Create conversations from different companies
conv1 = create_conversation_with_company(account, 'Acme Corp')
conv2 = create_conversation_with_company(account, 'TechCorp Inc')

puts "Created conversation #{conv1.id} with company: Acme Corp"
puts "Created conversation #{conv2.id} with company: TechCorp Inc"

# Create JIRA issue links
issue_key = 'TEST-123'

# Link first conversation
link1 = JiraIssueLink.create!(
  conversation: conv1,
  issue_key: issue_key,
  account: account,
  linked_at: Time.current
)

puts "Linked conversation #{conv1.id} to issue #{issue_key}"

# Check what organization labels would be gathered for this issue
# Simulate the Current.account context
Current.account = account

# Create a mock controller instance to access the private method
controller_class = Api::V1::Accounts::Integrations::JiraController
labels_after_first_link = controller_class.new.send(:get_all_organization_labels_for_issue, issue_key)
puts "Labels after first link: #{labels_after_first_link}"

# Link second conversation to same issue
link2 = JiraIssueLink.create!(
  conversation: conv2,
  issue_key: issue_key,
  account: account,
  linked_at: Time.current
)

puts "Linked conversation #{conv2.id} to issue #{issue_key}"

# Check what organization labels would be gathered now
labels_after_second_link = controller.send(:get_all_organization_labels_for_issue, issue_key)
puts "Labels after second link: #{labels_after_second_link}"

puts "=== Expected: ['acme_corp', 'techcorp_inc'] ==="
puts "=== Actual: #{labels_after_second_link} ==="

if labels_after_second_link.include?('acme_corp') && labels_after_second_link.include?('techcorp_inc')
  puts "✅ SUCCESS: Both company labels are present"
else
  puts "❌ FAILURE: Missing expected company labels"
end
