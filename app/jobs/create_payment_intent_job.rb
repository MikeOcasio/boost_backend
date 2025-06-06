require 'stripe'

class CreatePaymentIntentJob < ApplicationJob
  queue_as :default

  def perform(order_id)
    order = Order.find(order_id)

    # Only create payment intent if order is assigned and doesn't have one yet
    # Most orders should already have a PaymentIntent from checkout - this is mainly for edge cases
    return unless order.assigned? && order.assigned_skill_master_id.present? && order.stripe_payment_intent_id.blank?

    Rails.logger.info "Creating PaymentIntent for order #{order.id} - no existing PaymentIntent found"

    Stripe.api_key = Rails.application.credentials.stripe[:test_secret]

    begin
      # Find the skillmaster and their contractor account
      skillmaster = User.find(order.assigned_skill_master_id)
      contractor = skillmaster.contractor

      # Create or find Stripe customer for the order user
      customer = find_or_create_stripe_customer(order.user)

      # Calculate amounts (65% to skillmaster, 35% to business)
      total_amount = (order.total_price * 100).to_i # Convert to cents
      skillmaster_amount = (order.total_price * 0.65 * 100).to_i
      business_amount = (order.total_price * 0.35 * 100).to_i

      # Payment intent parameters
      payment_intent_params = {
        amount: total_amount,
        currency: 'usd',
        customer: customer.id,
        capture_method: 'manual', # Manual capture - will capture when admin approves
        metadata: {
          order_id: order.id,
          internal_id: order.internal_id,
          skillmaster_id: skillmaster.id,
          skillmaster_amount: skillmaster_amount,
          business_amount: business_amount,
          user_id: order.user_id,
          created_by: 'CreatePaymentIntentJob'
        }
      }

      # Check if contractor account is ready for transfers
      if contractor&.stripe_account_id.present?
        begin
          # Check if the account can accept transfers
          account = Stripe::Account.retrieve(contractor.stripe_account_id)
          transfer_capable = account.capabilities&.transfers == 'active'

          if transfer_capable
            payment_intent_params[:transfer_data] = {
              destination: contractor.stripe_account_id,
              amount: skillmaster_amount
            }
            Rails.logger.info "Adding transfer data for contractor #{contractor.stripe_account_id}"
          else
            Rails.logger.warn "Contractor #{contractor.stripe_account_id} does not have transfer capabilities enabled. Will handle transfer manually."
          end
        rescue Stripe::StripeError => e
          Rails.logger.warn "Could not verify contractor account capabilities: #{e.message}. Will handle transfer manually."
        end
      end

      # Create the payment intent
      payment_intent = Stripe::PaymentIntent.create(payment_intent_params)

      # Update order with payment intent ID and earnings
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
