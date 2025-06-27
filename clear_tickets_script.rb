# Clear all tickets and JIRA links - Rails Console Script
# Run this in Rails console: bin/rails console < clear_tickets_script.rb

puts "Starting cleanup of tickets and JIRA links..."

# Count before cleanup
tickets_count = Ticket.count
jira_links_count = JiraIssueLink.count
puts "Before cleanup:"
puts "- Tickets: #{tickets_count}"
puts "- JIRA Issue Links: #{jira_links_count}"

# Option A: Clear JIRA data from tickets but keep tickets
puts "\n=== Option A: Clear JIRA data from tickets (keep tickets) ==="
puts "Clearing JIRA-related fields from tickets..."
Ticket.update_all(
  jira_issue_key: nil,
  jira_status: nil,
  jira_in_progress: nil
)

puts "Deleting all JIRA issue links..."
JiraIssueLink.delete_all

puts "JIRA data cleared from tickets, tickets preserved."

# Option B: Delete all tickets (uncomment if you want to delete everything)
# puts "\n=== Option B: Delete ALL tickets completely ==="
# puts "Deleting all tickets..."
# Ticket.delete_all
# puts "All tickets deleted."

# Count after cleanup
tickets_count_after = Ticket.count
jira_links_count_after = JiraIssueLink.count
puts "\nAfter cleanup:"
puts "- Tickets: #{tickets_count_after}"
puts "- JIRA Issue Links: #{jira_links_count_after}"

puts "\nCleanup completed!"
