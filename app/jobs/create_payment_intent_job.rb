require 'stripe'

class CreatePaymentIntentJob < ApplicationJob
  queue_as :default

  def perform(order_id)
    order = Order.find(order_id)

    # Only create payment intent if order is assigned and doesn't have one yet
    return unless order.assigned? && order.assigned_skill_master_id.present? && order.stripe_payment_intent_id.blank?

    Stripe.api_key = Rails.application.credentials.stripe[:secret_key]

    begin
      # Find the skillmaster and their contractor account
      skillmaster = User.find(order.assigned_skill_master_id)
      contractor = skillmaster.contractor

      # Create or find Stripe customer for the order user
      customer = find_or_create_stripe_customer(order.user)

      # Calculate amounts (60% to skillmaster, 40% to business)
      total_amount = (order.total_price * 100).to_i # Convert to cents
      skillmaster_amount = (order.total_price * 0.60 * 100).to_i
      business_amount = (order.total_price * 0.40 * 100).to_i

      # Payment intent parameters
      payment_intent_params = {
        amount: total_amount,
        currency: 'usd',
        customer: customer.id,
        capture_method: 'manual', # Manual capture - will capture when order completes
        metadata: {
          order_id: order.id,
          internal_id: order.internal_id,
          skillmaster_id: skillmaster.id,
          skillmaster_amount: skillmaster_amount,
          business_amount: business_amount,
          user_id: order.user_id
        }
      }

      # Add transfer data if contractor account exists
      if contractor&.stripe_account_id.present?
        payment_intent_params[:transfer_data] = {
          destination: contractor.stripe_account_id,
          amount: skillmaster_amount
        }
      end

      # Create the payment intent
      payment_intent = Stripe::PaymentIntent.create(payment_intent_params)

      # Update order with payment intent ID
      order.update!(
        stripe_payment_intent_id: payment_intent.id,
        skillmaster_earned: skillmaster_amount / 100.0, # Store as dollars
        company_earned: business_amount / 100.0
      )

      Rails.logger.info "Payment intent created for order #{order.id}: #{payment_intent.id} (Total: $#{order.total_price}, Skillmaster: $#{skillmaster_amount / 100.0}, Business: $#{business_amount / 100.0})"
    rescue Stripe::StripeError => e
      Rails.logger.error "Failed to create payment intent for order #{order.id}: #{e.message}"
      # You might want to retry this job or send an alert
      raise e
    end
  end

  private

  def find_or_create_stripe_customer(user)
    if user.stripe_customer_id.present?
      Stripe::Customer.retrieve(user.stripe_customer_id)
    else
      customer = Stripe::Customer.create({
                                           email: user.email,
                                           name: "#{user.first_name} #{user.last_name}",
                                           metadata: {
                                             user_id: user.id
                                           }
                                         })
      user.update!(stripe_customer_id: customer.id)
      customer
    end
  end
end
