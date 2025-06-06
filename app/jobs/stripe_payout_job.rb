require 'stripe'

class StripePayoutJob < ApplicationJob
  queue_as :default

  def perform(contractor_id, amount)
    contractor = Contractor.find(contractor_id)

    # Verify contractor has a valid Stripe account
    unless contractor.stripe_account_ready?
      Rails.logger.error "Cannot process payout for contractor #{contractor_id}: No valid Stripe account"
      return
    end

    # Convert amount to cents for Stripe
    amount_cents = (amount * 100).to_i

    # Minimum payout amount (Stripe requires at least $1.00)
    if amount_cents < 100
      Rails.logger.warn "Payout amount $#{amount} for contractor #{contractor_id} is below minimum ($1.00) - skipping payout"
      return
    end

    Stripe.api_key = Rails.application.credentials.stripe[:test_secret]

    begin
      # Create a transfer to the contractor's Stripe account
      transfer = Stripe::Transfer.create({
                                           amount: amount_cents,
                                           currency: 'usd',
                                           destination: contractor.stripe_account_id,
                                           metadata: {
                                             contractor_id: contractor_id,
                                             user_id: contractor.user_id,
                                             payout_type: 'admin_approved_earnings',
                                             processed_at: Time.current.to_i
                                           }
                                         })

      Rails.logger.info "Stripe payout processed for contractor #{contractor_id}: $#{amount} (Transfer ID: #{transfer.id})"

      # Optionally, you could store transfer ID for tracking
      # contractor.update!(last_payout_transfer_id: transfer.id, last_payout_at: Time.current)
    rescue Stripe::StripeError => e
      Rails.logger.error "Failed to process Stripe payout for contractor #{contractor_id}: #{e.message}"

      # Could implement retry logic or alert admins
      # For now, the money stays in available_balance and can be manually processed
      raise e
    end
  end
end
