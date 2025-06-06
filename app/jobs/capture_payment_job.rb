require 'stripe'

class CapturePaymentJob < ApplicationJob
  queue_as :default

  def perform(order_id)
    order = Order.find(order_id)

    # Only capture if order is complete, admin has reviewed, and payment hasn't been captured yet
    unless order.complete? && order.admin_reviewed_at.present? && order.stripe_payment_intent_id.present? && order.payment_captured_at.nil?
      Rails.logger.warn "Cannot capture payment for order #{order.id}: order must be complete (#{order.complete?}), admin reviewed (#{order.admin_reviewed_at.present?}), have payment intent (#{order.stripe_payment_intent_id.present?}), and not already captured (#{order.payment_captured_at.nil?})"
      return
    end

    Stripe.api_key = Rails.application.credentials.stripe[:test_secret]

    begin
      # First, retrieve the payment intent to check its status
      payment_intent = Stripe::PaymentIntent.retrieve(order.stripe_payment_intent_id)

      # Check if the payment intent is in a capturable state
      unless payment_intent.status == 'requires_capture'
        Rails.logger.warn "Cannot capture payment for order #{order.id}: PaymentIntent status is '#{payment_intent.status}'. Expected 'requires_capture'. Payment may not have been authorized yet."
        return
      end

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
        # Move the earnings from pending to available balance since admin approved
        approved_amount = contractor.approve_and_move_to_available(skillmaster_amount)

        # Update order with payment completion
        order.update!(
          payment_captured_at: Time.current,
          payment_status: 'captured'
        )

        Rails.logger.info "Payment captured for order #{order.id}: $#{total_amount} (Skillmaster: $#{skillmaster_amount}, Company: $#{company_amount}) - Moved $#{approved_amount} to available balance"
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
