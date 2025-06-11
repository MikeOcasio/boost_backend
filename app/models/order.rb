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
    in_review
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
  has_one :payment_approval, dependent: :destroy

  before_save :assign_platform_credentials
  before_create :generate_internal_id
  after_update :create_paypal_order_if_assigned
  after_update :add_earnings_to_pending_if_completed
  after_update :close_associated_chats_if_completed
  after_update :create_payment_approval_if_completed

  validates :state, inclusion: { in: VALID_STATES }
  validates :internal_id, uniqueness: true
  validates :user, presence: true

  # Completion data validations - only required when order is complete
  validates :before_image, presence: true, if: :completion_images_required?
  validates :after_image, presence: true, if: :completion_images_required?

  aasm column: 'state' do
    state :open, initial: true
    state :assigned
    state :in_progress
    state :delayed
    state :disputed
    state :re_assigned
    state :complete
    state :in_review

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
      transitions from: %i[assigned in_progress delayed complete], to: :disputed
    end

    event :re_assign do
      transitions from: %i[assigned in_progress disputed delayed], to: :re_assigned
    end

    event :mark_complete do
      # Skillmaster marks work as complete (but payment requires admin approval)
      transitions from: %i[in_progress delayed], to: :complete
    end

    event :reject_and_rework do
      # Admin rejects completed work and sends back for rework
      transitions from: :complete, to: :in_progress
    end

    event :mark_in_review do
      # Customer disputes after completion
      transitions from: :complete, to: :in_review
    end

    event :resolve_dispute do
      # Admin resolves customer dispute
      transitions from: :in_review, to: :complete
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

  def completion_images_required?
    state == 'complete' && state_changed? && state_was != 'complete'
  end

  def completion_data_required?
    state == 'complete' && state_changed? && state_was != 'complete'
  end

  # Clean up completion images from S3 if order is deleted or images are replaced
  def cleanup_completion_images
    [before_image, after_image].compact.each do |image_url|
      next unless image_url.present? && image_url.match?(%r{^https?://.*\.amazonaws\.com/})

      begin
        uri = URI.parse(image_url)
        key = uri.path[1..-1] # Remove the leading '/'
        Rails.application.config.s3_bucket.object(key).delete
      rescue StandardError => e
        Rails.logger.error "Failed to delete completion image from S3: #{e.message}"
      end
    end
  end

  private

  def create_paypal_order_if_assigned
    return unless saved_change_to_state? && state == 'assigned' && assigned_skill_master_id.present?

    # Calculate earnings if not already calculated
    if skillmaster_earned.nil? || company_earned.nil?
      skillmaster_amount = total_price * 0.65
      company_amount = total_price * 0.35

      update_columns(
        skillmaster_earned: skillmaster_amount,
        company_earned: company_amount
      )

      Rails.logger.info "Order #{id} assigned - calculated earnings: Skillmaster: $#{skillmaster_amount}, Company: $#{company_amount}"
    end

    # Create PayPal order when order is assigned to skillmaster (only if none exists)
    CreatePaypalOrderJob.perform_later(id)
  end

  def add_earnings_to_pending_if_completed
    return unless saved_change_to_state? && state == 'complete' && assigned_skill_master_id.present?

    # Only move to pending balance when skillmaster marks complete FOR THE FIRST TIME
    # Use submitted_for_review_at to track if earnings were already processed
    # Payment capture happens later during admin approval
    skillmaster = User.find(assigned_skill_master_id)
    if skillmaster&.contractor && skillmaster_earned.present? && submitted_for_review_at.blank?
      # First time completion - add earnings to pending balance and mark submission time
      skillmaster.contractor.add_to_pending_balance(skillmaster_earned)
      update_column(:submitted_for_review_at, Time.current)
      Rails.logger.info "Order #{id} completed - moved $#{skillmaster_earned} to skillmaster's pending balance (first completion)"
    elsif submitted_for_review_at.present?
      Rails.logger.info "Order #{id} completed again - earnings already processed at #{submitted_for_review_at}, skipping balance update"
    end
  end

  def close_associated_chats_if_completed
    return unless saved_change_to_state? && state == 'complete'

    chats.update_all(status: 'closed')
  end

  def create_payment_approval_if_completed
    return unless saved_change_to_state? && state == 'complete'
    return if payment_approval.present?

    # Create payment approval record when order is marked complete
    create_payment_approval!
    Rails.logger.info "Order #{id} completed - created payment approval record"
  end
end
