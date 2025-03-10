class Chat < ApplicationRecord
  belongs_to :initiator, class_name: 'User'
  belongs_to :recipient, class_name: 'User', optional: true
  belongs_to :order, optional: true
  has_many :messages, dependent: :destroy
  has_many :chat_participants, dependent: :destroy
  has_many :participants, through: :chat_participants, source: :user

  validates :chat_type, presence: true, inclusion: { in: %w[direct group support] }
  validates :status, presence: true, inclusion: { in: %w[active archived] }

  before_create :generate_ticket_number, if: :support_chat?
  before_create :validate_chat_permissions

  scope :active, -> { where(status: 'active') }
  scope :archived, -> { where(status: 'archived') }
  scope :support_tickets, -> { where(chat_type: 'support') }

  def archive!
    update(status: 'archived')
  end

  def support_chat?
    chat_type == 'support'
  end

  private

  def generate_ticket_number
    self.ticket_number = "TICKET-#{Time.current.to_i}-#{SecureRandom.hex(4).upcase}"
  end

  def validate_chat_permissions
    case chat_type
    when 'direct'
      validate_direct_chat
    when 'group'
      validate_group_chat
    when 'support'
      validate_support_chat
    end
  end

  def validate_direct_chat
    return true if order_based_chat? || internal_staff_chat?

    errors.add(:base, 'Invalid chat participants')
    false
  end

  def validate_group_chat
    return if participants.all? { |p| %w[skillmaster admin dev].include?(p.role) }

    errors.add(:base, 'Invalid group chat participants')
    false
  end

  def validate_support_chat
    return if initiator.role == 'customer' && recipient.role.in?(%w[admin dev])

    errors.add(:base, 'Invalid support chat participants')
    false
  end

  def order_based_chat?
    return false unless initiator.role == 'customer' && recipient.role == 'skillmaster'

    Order.exists?(
      user_id: initiator.id,
      assigned_skill_master_id: recipient.id,
      state: %w[assigned in_progress delayed disputed]
    )
  end

  def internal_staff_chat?
    initiator.role.in?(%w[skillmaster admin dev]) &&
      recipient.role.in?(%w[skillmaster admin dev])
  end
end
