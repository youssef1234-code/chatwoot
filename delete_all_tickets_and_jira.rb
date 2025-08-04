#!/usr/bin/env ruby
# Delete All Tickets and JIRA Links - Complete Cleanup Script
# Run this script with: bin/rails runner delete_all_tickets_and_jira.rb
# Or in Rails console: load 'delete_all_tickets_and_jira.rb'

puts "=" * 60
puts "CHATWOOT TICKETS & JIRA CLEANUP SCRIPT"
puts "=" * 60
puts "This script will completely remove:"
puts "- All tickets"
puts "- All ticket messages (links between tickets and messages)"
puts "- All JIRA issue links"
puts "- All JIRA-related data from tickets"
puts "=" * 60

# Ask for confirmation unless in non-interactive mode
unless defined?(Rails::Console) || ARGV.include?('--force')
  print "\nARE YOU SURE YOU WANT TO DELETE EVERYTHING? Type 'YES' to continue: "
  confirmation = gets.chomp
  unless confirmation == 'YES'
    puts "Operation cancelled. No changes were made."
    exit
  end
end

puts "\n🚀 Starting cleanup process..."

begin
  # Count before cleanup
  tickets_count = Ticket.count
  ticket_messages_count = TicketMessage.count
  jira_links_count = JiraIssueLink.count
  
  puts "\n📊 BEFORE CLEANUP:"
  puts "- Tickets: #{tickets_count}"
  puts "- Ticket Messages (links): #{ticket_messages_count}"
  puts "- JIRA Issue Links: #{jira_links_count}"

  # Step 1: Delete all ticket messages (the linking table)
  puts "\n🔗 Step 1: Deleting all ticket message links..."
  TicketMessage.delete_all
  puts "✅ Deleted all ticket message links"

  # Step 2: Delete all JIRA issue links
  puts "\n🔗 Step 2: Deleting all JIRA issue links..."
  JiraIssueLink.delete_all
  puts "✅ Deleted all JIRA issue links"

  # Step 3: Clear JIRA-related fields from any remaining tickets
  puts "\n🧹 Step 3: Clearing JIRA data from tickets..."
  Ticket.update_all(
    jira_issue_key: nil,
    jira_status: nil,
    jira_in_progress: nil
  )
  puts "✅ Cleared JIRA data from all tickets"

  # Step 4: Delete all tickets
  puts "\n🎫 Step 4: Deleting all tickets..."
  Ticket.delete_all
  puts "✅ Deleted all tickets"

  # Verify cleanup
  tickets_count_after = Ticket.count
  ticket_messages_count_after = TicketMessage.count
  jira_links_count_after = JiraIssueLink.count

  puts "\n📊 AFTER CLEANUP:"
  puts "- Tickets: #{tickets_count_after}"
  puts "- Ticket Messages (links): #{ticket_messages_count_after}"
  puts "- JIRA Issue Links: #{jira_links_count_after}"

  puts "\n✨ CLEANUP SUMMARY:"
  puts "- Deleted #{tickets_count} tickets"
  puts "- Deleted #{ticket_messages_count} ticket message links"
  puts "- Deleted #{jira_links_count} JIRA issue links"

  if tickets_count_after == 0 && ticket_messages_count_after == 0 && jira_links_count_after == 0
    puts "\n🎉 SUCCESS: All tickets and JIRA data have been completely removed!"
  else
    puts "\n⚠️  WARNING: Some data may still exist. Please check manually."
  end

rescue StandardError => e
  puts "\n❌ ERROR occurred during cleanup:"
  puts "Error: #{e.message}"
  puts "Backtrace:"
  puts e.backtrace.first(5).join("\n")
  puts "\nPlease check the database state and try again."
end

puts "\n" + "=" * 60
puts "CLEANUP SCRIPT COMPLETED"
puts "=" * 60
