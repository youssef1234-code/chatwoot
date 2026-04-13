class Api::V1::Accounts::Conversations::ContactParticipantsController < Api::V1::Accounts::Conversations::BaseController
  def show
    contact_ids = @conversation.custom_attributes&.dig('group_member_contact_ids')

    if contact_ids.is_a?(Array) && contact_ids.any?
      @contacts = Current.account.contacts
                         .where(id: contact_ids)
                         .order(:name)
    else
      # Fallback: show contacts who sent messages in this conversation
      sender_ids = @conversation.messages.reorder('')
                                .where(sender_type: 'Contact')
                                .where.not(sender_id: @conversation.contact_id)
                                .distinct.pluck(:sender_id)

      @contacts = Current.account.contacts
                         .where(id: sender_ids)
                         .order(:name)
    end
  end
end
