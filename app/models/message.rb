class Message < ApplicationRecord
  belongs_to :chat
  belongs_to :sender, class_name: 'User'

  validates :content, presence: true
  validates :sender_id, presence: true
  validates :chat_id, presence: true

  after_create_commit { broadcast_message }

  private

  def broadcast_message
    ChatChannel.broadcast_to(
      chat,
      {
        type: 'new_message',
        **serialize_message_data
      }
    )
  end

  def serialize_message_data
    {
      id: id,
      content: content,
      created_at: created_at,
      updated_at: updated_at,
      read: read,
      sender: {
        id: sender.id,
        first_name: sender.first_name,
        last_name: sender.last_name,
        email: sender.email,
        role: sender.role,
        image_url: sender.image_url
      }
    }
  end
end
