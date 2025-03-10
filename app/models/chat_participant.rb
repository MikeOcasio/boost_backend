class ChatParticipant < ApplicationRecord
  belongs_to :chat
  belongs_to :user

  validates :user_id, uniqueness: { scope: :chat_id }
  validate :validate_participant_role

  private

  def validate_participant_role
    return if chat.chat_type != 'group'

    return if user.role.in?(%w[skillmaster admin dev])

    errors.add(:base, 'Invalid participant role for group chat')
  end
end
