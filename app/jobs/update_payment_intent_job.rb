require 'stripe'

class UpdatePaymentIntentJob < ApplicationJob
  queue_as :default

  def perform(order_id, new_skillmaster_id)
    order = Order.find(order_id)

    # Ensure we have a payment intent to update
    return unless order.stripe_payment_intent_id.present?

    Stripe.api_key = Rails.application.credentials.stripe[:test_secret]

    begin
      # Get the new skillmaster and their contractor account
      new_skillmaster = User.find(new_skillmaster_id)
      new_contractor = new_skillmaster.contractor

      # Update payment intent metadata with new contractor information
      metadata = {
        order_id: order.id,
        original_skillmaster_id: order.assigned_skill_master_id_was || 'unknown',
        current_skillmaster_id: new_skillmaster_id,
        skillmaster_name: "#{new_skillmaster.first_name} #{new_skillmaster.last_name}",
        reassignment_timestamp: Time.current.to_i,
        reassignment_reason: 'order_reassignment'
      }

      # Add contractor account ID if available
      if new_contractor&.stripe_account_id.present?
        metadata[:contractor_stripe_account_id] = new_contractor.stripe_account_id
      else
        metadata[:contractor_stripe_account_id] = 'pending_account_creation'
        Rails.logger.warn "Order #{order_id} reassigned to skillmaster #{new_skillmaster_id} who doesn't have a contractor account yet"
      end

      # Update the payment intent metadata
      Stripe::PaymentIntent.update(
        order.stripe_payment_intent_id,
        metadata: metadata
      )

      Rails.logger.info "Updated payment intent #{order.stripe_payment_intent_id} for reassigned order #{order_id}. New skillmaster: #{new_skillmaster_id}"
    rescue Stripe::StripeError => e
      Rails.logger.error "Failed to update payment intent for order #{order_id}: #{e.message}"
      # Could implement retry logic or alert admins
      raise e
    rescue StandardError => e
      Rails.logger.error "Unexpected error updating payment intent for order #{order_id}: #{e.message}"
      raise e
    end
  end
end
