class MessageFinder
  def initialize(conversation, params)
    @conversation = conversation
    @params = params
  end

  def perform
    current_messages
  end

  private

  def conversation_messages
    @conversation.messages.includes(:attachments, :sender, sender: { avatar_attachment: [:blob] })
  end

  def messages
    return conversation_messages if @params[:filter_internal_messages].blank?

    conversation_messages.where.not('private = ? OR message_type = ?', true, 2)
  end

  def current_messages
    if @params[:after].present? && @params[:before].present?
      messages_between(@params[:after].to_i, @params[:before].to_i)
    elsif @params[:before].present?
      messages_before(@params[:before].to_i)
    elsif @params[:after].present?
      messages_after(@params[:after].to_i)
    else
      messages_latest
    end
  end

  # Resolve the created_at timestamp of a cursor message ID.
  # When IDs are non-monotonic with created_at (e.g. media messages inserted
  # after text messages during bulk sync), ID-based filtering drops messages.
  # Using created_at for both filtering and ordering keeps pagination consistent.
  def cursor_timestamp(message_id)
    @conversation.messages.where(id: message_id).pick(:created_at)
  end

  def messages_after(after_id)
    ts = cursor_timestamp(after_id)
    return messages.reorder('created_at asc').where('id > ?', after_id).limit(100) unless ts

    messages.reorder('created_at asc').where('created_at > ? OR (created_at = ? AND id > ?)', ts, ts, after_id).limit(100)
  end

  def messages_before(before_id)
    ts = cursor_timestamp(before_id)
    return messages.reorder('created_at desc').where('id < ?', before_id).limit(20).reverse unless ts

    messages.reorder('created_at desc').where('created_at < ? OR (created_at = ? AND id < ?)', ts, ts, before_id).limit(20).reverse
  end

  def messages_between(after_id, before_id)
    after_ts = cursor_timestamp(after_id)
    before_ts = cursor_timestamp(before_id)
    return messages.reorder('created_at asc').where('id >= ? AND id < ?', after_id, before_id).limit(1000) unless after_ts && before_ts

    messages.reorder('created_at asc')
            .where('(created_at > ? OR (created_at = ? AND id >= ?)) AND (created_at < ? OR (created_at = ? AND id < ?))',
                   after_ts, after_ts, after_id, before_ts, before_ts, before_id)
            .limit(1000)
  end

  def messages_latest
    messages.reorder('created_at desc').limit(20).reverse
  end
end
