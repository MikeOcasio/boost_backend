require 'stripe'

class CapturePaymentJob < ApplicationJob
  queue_as :default

  def perform(order_id)
    order = Order.find(order_id)

    # Only capture if order is complete and payment hasn't been captured yet
    return unless order.complete? && order.stripe_payment_intent_id.present? && order.payment_captured_at.nil?

    Stripe.api_key = Rails.application.credentials.stripe[:secret_key]

    begin
      # Capture the payment
      payment_intent = Stripe::PaymentIntent.capture(order.stripe_payment_intent_id)

      # Get split amounts from order (already calculated when payment intent was created)
      total_amount = payment_intent.amount / 100.0 # Convert from cents
      skillmaster_amount = order.skillmaster_earned || (total_amount * 0.60)
      company_amount = order.company_earned || (total_amount * 0.40)

      # Find skillmaster's contractor record
      skillmaster = User.find(order.assigned_skill_master_id)
      contractor = skillmaster.contractor

      if contractor.present?
        # Add to skillmaster's pending balance
        contractor.add_to_pending_balance(skillmaster_amount)

        # Update order with payment completion
        order.update!(
          payment_captured_at: Time.current,
          payment_status: 'captured',
          skillmaster_earned: skillmaster_amount,
          company_earned: company_amount
        )

        Rails.logger.info "Payment captured for order #{order.id}: $#{total_amount} (Skillmaster: $#{skillmaster_amount}, Company: $#{company_amount})"
      else
        # If no contractor account exists, still capture payment but note missing contractor
        order.update!(
          payment_captured_at: Time.current,
          payment_status: 'captured',
          skillmaster_earned: skillmaster_amount,
          company_earned: company_amount
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
