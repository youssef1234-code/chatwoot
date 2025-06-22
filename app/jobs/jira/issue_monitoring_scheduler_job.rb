class Jira::IssueMonitoringSchedulerJob < ApplicationJob
  queue_as :low

  def perform
    Rails.logger.info("JIRA: Starting periodic issue status monitoring")
    
    # Find all accounts with JIRA integration enabled
    accounts_with_jira = Account.joins(:hooks)
                               .where(hooks: { app_id: 'jira', status: 'enabled' })
                               .distinct
    
    Rails.logger.info("JIRA: Found #{accounts_with_jira.count} accounts with JIRA integration")
    
    accounts_with_jira.find_each do |account|
      monitor_account_issues(account)
    end
  end

  private

  def monitor_account_issues(account)
    Rails.logger.info("JIRA: Monitoring issues for account #{account.id}")
    
    # Get all issue links that need status checking and haven't been completed yet
    stale_links = JiraIssueLink.where(account: account)
                              .with_notifications_enabled
                              .stale_status_check
                              .where.not(last_known_status: ['Done', 'Resolved', 'Closed', 'Complete', 'Completed'])
    
    # Group by issue_key to avoid duplicate API calls
    unique_issue_keys = stale_links.distinct.pluck(:issue_key)
    
    return if unique_issue_keys.empty?
    
    Rails.logger.info("JIRA: Found #{unique_issue_keys.count} issues needing status check for account #{account.id}")
    
    # Schedule status update jobs for each issue (with rate limiting)
    unique_issue_keys.each_with_index do |issue_key, index|
      # Stagger the jobs to avoid overwhelming JIRA API
      delay = index * 5.seconds
      
      Jira::IssueStatusUpdateJob.set(wait: delay).perform_later(
        issue_key: issue_key,
        account_id: account.id
      )
    end
  end
end
