# == Schema Information
#
# Table name: orders
#
#  id         :bigint           not null, primary key
#  user_id    :bigint           not null
#  product_id :bigint           not null
#  status     :string
#  total_price: decimal
#  created_at :datetime         not null
#  updated_at :datetime         not null'
#  internal_id: string
#
# Relationships
# - belongs_to :user
# - belongs_to :product

class Order < ApplicationRecord
  include AASM

  VALID_STATES = %w[
    open
    assigned
    in_progress
    delayed
    disputed
    re_assigned
    complete
  ].freeze

  scope :graveyard_orders, -> { where(assigned_skill_master_id: nil) }
  scope :completed, -> { where(state: 'complete') }

  belongs_to :user
  belongs_to :platform_credential, optional: true
  belongs_to :assigned_skill_master, class_name: 'User', optional: true
  has_many :order_products, dependent: :destroy
  has_many :products, through: :order_products
  has_one :promotion
  has_many :reviews, dependent: :destroy
  has_many :chats, dependent: :nullify

  before_save :assign_platform_credentials
  before_create :generate_internal_id
  after_update :capture_payment_if_completed
  after_update :close_associated_chats_if_completed

  validates :state, inclusion: { in: VALID_STATES }
  validates :internal_id, uniqueness: true
  validates :user, presence: true

  aasm column: 'state' do
    state :open, initial: true
    state :assigned
    state :in_progress
    state :delayed
    state :disputed
    state :re_assigned
    state :complete

    # Define state transitions
    event :assign do
      # Transition from `open` to `assigned` only if `assigned_skill_master_id` is set
      transitions from: %i[re_assigned open], to: :assigned, guard: :skill_master_assigned?
    end

    event :start_progress do
      transitions from: :assigned, to: :in_progress # ! Need to add reassign logic
    end

    event :mark_delayed do
      transitions from: :in_progress, to: :delayed
    end

    event :mark_disputed do
      transitions from: %i[assigned in_progress delayed], to: :disputed
    end

    event :re_assign do
      transitions from: %i[assigned in_progress disputed delayed], to: :re_assigned
    end

    event :complete_order do
      transitions from: %i[in_progress delayed], to: :complete
    end
  end

  def generate_internal_id
    self.internal_id = SecureRandom.hex(5) # generates a random 20-character string
  end

  def assign_platform_credentials
    return unless platform_credential.nil? && user.present? && platform.present?

    self.platform_credential = user.platform_credentials.find_by(platform_id: platform)
  end

  def skill_master_assigned?
    assigned_skill_master_id.present?
  end

  private

  def capture_payment_if_completed
    return unless saved_change_to_state? && state == 'complete' && stripe_payment_intent_id.present?

    CapturePaymentJob.perform_later(id)
  end

  def close_associated_chats_if_completed
    return unless saved_change_to_state? && state == 'complete'

    chats.active.each do |chat|
      chat.close!
      # Broadcast chat closure to WebSocket subscribers
      ActionCable.server.broadcast("chat_#{chat.id}", {
        type: 'chat_closed',
        message: 'Chat has been automatically closed because the order is complete.',
        chat_id: chat.id,
        closed_at: chat.closed_at
      })
    end
  end
end
