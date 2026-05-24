# Computes the inbox allow-list for a channel-restricted administrator so report
# builders can scope their data. Returns nil when there is no restriction.
module ReportInboxScoping
  extend ActiveSupport::Concern

  private

  def report_scoped_inbox_ids
    ac_user = Current.account_user
    ac_user&.inbox_access_restricted? ? ac_user.cleaned_allowed_inbox_ids : nil
  end
end
