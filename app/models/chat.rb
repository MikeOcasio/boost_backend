class Chat < ApplicationRecord
  belongs_to :initiator, class_name: 'User'
  belongs_to :recipient, class_name: 'User', optional: true
  belongs_to :order, optional: true
  has_many :messages, dependent: :destroy
  has_many :chat_participants, dependent: :destroy
  has_many :participants, through: :chat_participants, source: :user

  validates :chat_type, presence: true, inclusion: { in: %w[direct group support] }
  validates :status, presence: true, inclusion: { in: %w[active archived] }
  validates :initiator_id,
            uniqueness: { scope: %i[recipient_id chat_type], message: 'Chat already exists between these users' }
  validate :prevent_self_chat

  before_create :generate_ticket_number, if: :support_chat?
  before_create :validate_chat_permissions

  scope :active, -> { where(status: 'active') }
  scope :archived, -> { where(status: 'archived') }
  scope :support_tickets, -> { where(chat_type: 'support') }

  validate :validate_direct_chat, if: -> { chat_type == 'direct' }
  validate :validate_group_chat, if: -> { chat_type == 'group' }
  validate :validate_support_chat, if: -> { chat_type == 'support' }

  VALID_ORDER_STATES = %w[assigned in_progress delayed disputed].freeze

  def archive!
    update(status: 'archived')
  end

  def support_chat?
    chat_type == 'support'
  end

  private

  def prevent_self_chat
    return unless initiator_id.present? && recipient_id.present? && initiator_id == recipient_id

    errors.add(:recipient_id, 'cannot be the same as the initiator')
  end

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
    return true unless chat_type == 'direct'
    return true unless initiator&.customer? && recipient&.skillmaster?

    unless order.present? &&
           VALID_ORDER_STATES.include?(order.state) &&
           order.assigned_skill_master_id == recipient.id &&
           order.user_id == initiator.id
      errors.add(:base, 'Cannot create chat without an active order')
    end
  end

  def validate_group_chat
    return true if initiator.role.in?(%w[admin dev c_support manager]) && chat_type == 'group'

    errors.add(:base, 'Group chat requires at least two participants')
  end

  def validate_support_chat
    return if initiator.role == 'customer' && recipient.role.in?(%w[admin dev c_support manager])

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
    initiator.role.in?(%w[skillmaster admin dev c_support manager]) &&
      recipient.role.in?(%w[skillmaster admin dev c_support manager])
  end
end
