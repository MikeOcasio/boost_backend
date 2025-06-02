class Chat < ApplicationRecord
  belongs_to :initiator, class_name: 'User'
  belongs_to :recipient, class_name: 'User', optional: true
  belongs_to :order, optional: true
  has_many :messages, dependent: :destroy
  has_many :chat_participants, dependent: :destroy
  has_many :participants, through: :chat_participants, source: :user

  validates :chat_type, presence: true, inclusion: { in: %w[direct group support] }
  validates :status, presence: true, inclusion: { in: %w[active archived closed locked] }
  validates :initiator_id,
            uniqueness: { scope: %i[recipient_id chat_type], message: 'Chat already exists between these users' }
  validate :prevent_self_chat
  validates :reopen_count, presence: true, numericality: { greater_than_or_equal_to: 0 }

  before_create :generate_ticket_number, if: :support_chat?
  before_create :validate_chat_permissions
  after_create :generate_reference_id

  scope :active, -> { where(status: 'active') }
  scope :archived, -> { where(status: 'archived') }
  scope :closed, -> { where(status: 'closed') }
  scope :locked, -> { where(status: 'locked') }
  scope :support_tickets, -> { where(chat_type: 'support') }

  validate :validate_direct_chat, if: -> { chat_type == 'direct' }
  validate :validate_group_chat, if: -> { chat_type == 'group' }
  validate :validate_support_chat, if: -> { chat_type == 'support' }

  VALID_ORDER_STATES = %w[assigned in_progress delayed disputed].freeze

  def archive!
    update(status: 'archived')
  end

  def close!
    update(status: 'closed', closed_at: Time.current)
  end

  def lock!
    update(status: 'locked', closed_at: Time.current)
  end

  def reopen!
    return false if locked?

    if closed? || archived?
      increment!(:reopen_count)
      update(status: 'active', reopened_at: Time.current)
      true
    else
      false
    end
  end

  def closed?
    status == 'closed'
  end

  def locked?
    status == 'locked'
  end

  def can_reopen?
    closed? || archived?
  end

  def can_close?
    active?
  end

  def active?
    status == 'active'
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

  def generate_reference_id
    # Format: MMDDYYYY-Order_ID-Chat_ID
    return unless order_id.present?

    date_part = Time.current.strftime('%m%d%Y')
    ref_id = "#{date_part}-#{order_id}-#{id}"
    update_column(:reference_id, ref_id)
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
