class Contractor < ApplicationRecord
  belongs_to :user
  has_many :paypal_payouts, dependent: :destroy

  validates :paypal_payout_email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true

  after_create :process_retroactive_payments_if_paypal_account_added
  after_update :process_retroactive_payments_if_paypal_account_added

  # Check if contractor can receive payouts (simplified - just needs PayPal email)
  def can_receive_payouts?
    paypal_payout_email.present? && paypal_email_verified?
  end

  # Withdrawal cooldown configuration
  WITHDRAWAL_COOLDOWN_DAYS = 7

  # Basic balance and withdrawal methods
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
    # NOTE: total_earned is only updated when admin approves and moves to available balance
  end

  def move_pending_to_available
    return 0 if pending_balance <= 0

    amount = pending_balance
    transaction do
      update!(
        available_balance: available_balance + amount,
        pending_balance: 0,
        total_earned: total_earned + amount
      )
    end
    amount
  end

  def approve_and_move_to_available(amount)
    return 0 if pending_balance < amount

    transaction do
      update!(
        available_balance: available_balance + amount,
        pending_balance: pending_balance - amount,
        total_earned: total_earned + amount
      )

      # Process payout if PayPal account is ready
      if paypal_account_ready?
        PaypalPayoutJob.perform_later(id, amount)
      else
        Rails.logger.warn "Contractor #{id} earnings approved but PayPal account not ready"
      end
    end
    amount
  end

  # Check if contractor has a valid PayPal account
  def paypal_account_ready?
    paypal_payout_email.present?
  end

  # Process retroactive payments when PayPal account is added
  def process_retroactive_payments_if_paypal_account_added
    # Handle both create (new contractor with paypal_payout_email) and update (adding paypal_payout_email to existing contractor)
    paypal_account_added = if persisted? && saved_changes.key?('paypal_payout_email')
                             # Update case: paypal_payout_email was changed
                             saved_change_to_paypal_payout_email? && paypal_payout_email.present?
                           else
                             # Create case: new record with paypal_payout_email
                             paypal_payout_email.present?
                           end

    return unless paypal_account_added

    Rails.logger.info "PayPal account added for contractor #{id} (user: #{user_id}). Processing retroactive payments..."

    # Queue job to process retroactive payments
    ProcessRetroactivePaymentsJob.perform_later(id)
  end
end
