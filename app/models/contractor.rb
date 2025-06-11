class Contractor < ApplicationRecord
  belongs_to :user
  has_many :paypal_payouts, dependent: :destroy

  validates :paypal_payout_email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :trolley_recipient_id, uniqueness: true, allow_blank: true
  validates :tax_form_status, inclusion: { in: %w[pending submitted approved rejected] }
  validates :tax_form_type, inclusion: { in: %w[W-9 W-8BEN] }, allow_blank: true
  validates :trolley_account_status, inclusion: { in: %w[pending active suspended] }

  after_create :process_retroactive_payments_if_paypal_account_added
  after_update :process_retroactive_payments_if_paypal_account_added

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
      # total_earned is incremented here since this represents admin-approved earnings
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

      # Check tax compliance before processing payout
      if paypal_account_ready? && tax_compliant?
        PaypalPayoutJob.perform_later(id, amount)
      else
        Rails.logger.warn "Contractor #{id} earnings approved but account not ready - payout will be processed when requirements are met"
      end
    end
    amount
  end

  # Check if contractor has a valid PayPal account and tax compliance
  def paypal_account_ready?
    paypal_payout_email.present? && trolley_account_status == 'active'
  end

  def tax_compliant?
    tax_form_status == 'approved' && tax_form_type.present?
  end

  def can_receive_payouts?
    paypal_account_ready? && tax_compliant?
  end

  def tax_form_required?
    # US residents need W-9, non-US residents need W-8BEN
    # This could be determined by user location or other criteria
    true # For now, assume all contractors need tax forms
  end

  def submit_tax_form!(form_type, form_data = {})
    update!(
      tax_form_type: form_type,
      tax_form_status: 'submitted',
      tax_form_submitted_at: Time.current
    )

    # Queue job to verify tax form with Trolley
    TrolleyTaxVerificationJob.perform_later(id, form_data)
  end

  def approve_tax_form!
    update!(
      tax_form_status: 'approved',
      tax_compliance_checked_at: Time.current
    )
  end

  def reject_tax_form!
    update!(tax_form_status: 'rejected')
  end # Process retroactive payments when PayPal account is added

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
