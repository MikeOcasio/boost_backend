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
        id: id,
        content: content,
        sender_id: sender_id,
        created_at: created_at,
        sender_name: sender.first_name
      }
    )
  end
end
