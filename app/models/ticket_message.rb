# == Schema Information
#
# Table name: ticket_messages
#
#  id         :bigint           not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  message_id :bigint           not null
#  ticket_id  :bigint           not null
#
# Indexes
#
#  index_ticket_messages_on_message_id                (message_id)
#  index_ticket_messages_on_ticket_id                 (ticket_id)
#  index_ticket_messages_on_ticket_id_and_message_id  (ticket_id,message_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (message_id => messages.id)
#  fk_rails_...  (ticket_id => tickets.id)
#

class TicketMessage < ApplicationRecord
  belongs_to :ticket
  belongs_to :message

  validates :ticket_id, uniqueness: { scope: :message_id, message: "Message is already linked to this ticket" }

  scope :for_ticket, ->(ticket_id) { where(ticket_id: ticket_id) }
  scope :for_message, ->(message_id) { where(message_id: message_id) }

  def self.link_message_to_ticket(ticket, message)
    create!(ticket: ticket, message: message)
  end

  def self.unlink_message_from_ticket(ticket_id, message_id)
    where(ticket_id: ticket_id, message_id: message_id).destroy_all
  end
end
