# Scopes report queries to a channel-restricted administrator's allowed inboxes.
# Builders receive the allow-list via params[:scoped_inbox_ids]; when blank,
# queries are left untouched (normal admin / no restriction).
module V2::Reports::InboxScopable
  private

  def scoped_inbox_ids
    params[:scoped_inbox_ids].presence
  end

  # reporting_events and conversations both have an inbox_id column.
  def scope_by_inbox(relation)
    return relation if scoped_inbox_ids.blank?

    relation.where(inbox_id: scoped_inbox_ids)
  end
end
