class Plane::IssueMonitoringSchedulerJob < ApplicationJob
  queue_as :low

  def perform
    Rails.logger.info("Plane: Starting periodic issue state monitoring")

    # Find all accounts with Plane integration enabled
    accounts_with_plane = Account.joins(:hooks)
                                 .where(hooks: { app_id: 'plane', status: 'enabled' })
                                 .distinct

    Rails.logger.info("Plane: Found #{accounts_with_plane.count} accounts with Plane integration")

    accounts_with_plane.find_each do |account|
      monitor_account_issues(account)
    end
  end

  private

  def monitor_account_issues(account)
    Rails.logger.info("Plane: Monitoring issues for account #{account.id}")

    # Get all issue links that need state checking and haven't been completed yet
    stale_links = PlaneIssueLink.where(account: account)
                                .with_notifications_enabled
                                .stale_state_check
                                .where.not(last_known_state: %w[Done Completed Closed Cancelled])

    # Group by issue_id+project_id to avoid duplicate API calls
    unique_issues = stale_links.distinct.pluck(:issue_id, :project_id)

    return if unique_issues.empty?

    Rails.logger.info("Plane: Found #{unique_issues.count} issues needing state check for account #{account.id}")

    # Schedule status update jobs for each issue (with rate limiting)
    unique_issues.each_with_index do |(issue_id, project_id), index|
      # Stagger the jobs to avoid overwhelming Plane API
      delay = index * 5.seconds

      Plane::IssueStatusUpdateJob.set(wait: delay).perform_later(
        issue_id: issue_id,
        project_id: project_id,
        account_id: account.id
      )
    end
  end
end
