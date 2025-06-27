# Clear tickets and JIRA links Rake task
# Place this in lib/tasks/clear_tickets.rake

namespace :tickets do
  desc "Clear all JIRA links and optionally all tickets"
  task :clear_jira_data => :environment do
    puts "Starting JIRA data cleanup..."
    
    # Count before
    tickets_count = Ticket.count
    jira_links_count = JiraIssueLink.count
    puts "Before cleanup: #{tickets_count} tickets, #{jira_links_count} JIRA links"
    
    # Clear JIRA data from tickets
    Ticket.update_all(
      jira_issue_key: nil,
      jira_status: nil,
      jira_in_progress: nil
    )
    
    # Delete all JIRA issue links
    JiraIssueLink.delete_all
    
    # Count after
    jira_links_count_after = JiraIssueLink.count
    puts "After cleanup: #{tickets_count} tickets, #{jira_links_count_after} JIRA links"
    puts "JIRA data cleared successfully!"
  end
  
  desc "Delete ALL tickets completely"
  task :delete_all => :environment do
    puts "WARNING: This will delete ALL tickets!"
    puts "Type 'yes' to confirm:"
    
    response = STDIN.gets.chomp
    if response.downcase == 'yes'
      tickets_count = Ticket.count
      
      # Delete related records first
      TicketMessage.delete_all
      JiraIssueLink.delete_all
      Ticket.delete_all
      
      puts "Deleted #{tickets_count} tickets and all related data."
    else
      puts "Operation cancelled."
    end
  end
end
