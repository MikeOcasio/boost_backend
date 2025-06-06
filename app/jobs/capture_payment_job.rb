require 'stripe'

class CapturePaymentJob < ApplicationJob
  queue_as :default

  def perform(order_id)
    order = Order.find(order_id)

    # Only capture if order is complete and payment hasn't been captured yet
    return unless order.complete? && order.stripe_payment_intent_id.present? && order.payment_captured_at.nil?

    Stripe.api_key = Rails.application.credentials.stripe[:test_secret]

    begin
      # Capture the payment
      payment_intent = Stripe::PaymentIntent.capture(order.stripe_payment_intent_id)

      # Get split amounts from order (already calculated when payment intent was created)
      total_amount = payment_intent.amount / 100.0 # Convert from cents

      # Use the amounts already stored in the order (calculated during payment intent creation)
      # This ensures consistency and avoids percentage calculation discrepancies
      skillmaster_amount = order.skillmaster_earned
      company_amount = order.company_earned

      # Fallback calculation if amounts aren't stored (shouldn't happen in normal flow)
      if skillmaster_amount.nil? || company_amount.nil?
        skillmaster_amount = total_amount * 0.65
        company_amount = total_amount * 0.35
        Rails.logger.warn "Order #{order.id} missing stored earnings, using fallback calculation"
      end

      # Find skillmaster's contractor record
      skillmaster = User.find(order.assigned_skill_master_id)
      contractor = skillmaster.contractor

      if contractor.present?
        # Add to skillmaster's pending balance (will be moved to available when admin approves)
        contractor.add_to_pending_balance(skillmaster_amount)

        # Update order with payment completion (don't overwrite earnings - they're already correct)
        order.update!(
          payment_captured_at: Time.current,
          payment_status: 'captured'
        )

        Rails.logger.info "Payment captured for order #{order.id}: $#{total_amount} (Skillmaster: $#{skillmaster_amount}, Company: $#{company_amount}) - Added to pending balance"
      else
        # If no contractor account exists, still capture payment but note missing contractor
        order.update!(
          payment_captured_at: Time.current,
          payment_status: 'captured'
        )

        Rails.logger.warn "Payment captured for order #{order.id} but no contractor account found for skillmaster #{skillmaster.id}. Payment will be held until contractor account is created."
      end
    rescue Stripe::StripeError => e
      Rails.logger.error "Failed to capture payment for order #{order.id}: #{e.message}"
      # You might want to retry this job or send an alert
      raise e
    end
  end
end
