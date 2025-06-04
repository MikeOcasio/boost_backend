class Contractor < ApplicationRecord
  belongs_to :user

  validates :stripe_account_id, uniqueness: true, allow_blank: true

  after_create :process_retroactive_payments_if_stripe_account_added
  after_update :process_retroactive_payments_if_stripe_account_added

  # Add these new columns in a migration
  # available_balance: decimal, default: 0.0
  # pending_balance: decimal, default: 0.0
  # last_withdrawal_at: datetime
  # total_earned: decimal, default: 0.0

  WITHDRAWAL_COOLDOWN_DAYS = 7

  def can_withdraw?
    return true if last_withdrawal_at.nil?

    last_withdrawal_at < WITHDRAWAL_COOLDOWN_DAYS.days.ago
  end

  def days_until_next_withdrawal
    return 0 if can_withdraw?

    WITHDRAWAL_COOLDOWN_DAYS - (Date.current - last_withdrawal_at.to_date).to_i
  end

  def add_to_available_balance(amount)
    increment!(:available_balance, amount)
    increment!(:total_earned, amount)
  end

  def add_to_pending_balance(amount)
    increment!(:pending_balance, amount)
  end

  def move_pending_to_available
    return 0 if pending_balance <= 0

    amount = pending_balance
    transaction do
      update!(
        available_balance: available_balance + amount,
        pending_balance: 0
      )
    end
    amount
  end

  # Check if contractor has a valid Stripe account
  def stripe_account_ready?
    stripe_account_id.present?
  end # Outlier XX: Process retroactive payments when Stripe account is added

  def process_retroactive_payments_if_stripe_account_added
    # Handle both create (new contractor with stripe_account_id) and update (adding stripe_account_id to existing contractor)
    stripe_account_added = if persisted? && saved_changes.key?('stripe_account_id')
                             # Update case: stripe_account_id was changed
                             saved_change_to_stripe_account_id? && stripe_account_id.present?
                           else
                             # Create case: new record with stripe_account_id
                             stripe_account_id.present?
                           end

    return unless stripe_account_added

    Rails.logger.info "Stripe account added for contractor #{id} (user: #{user_id}). Processing retroactive payments..."

    # Queue job to process retroactive payments
    ProcessRetroactivePaymentsJob.perform_later(id)
  end
end
