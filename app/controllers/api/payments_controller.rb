class Api::PaymentsController < ApplicationController
  def create_payment_intent
    # Get the cart details from the request body
    cart = params[:cart]

    # Calculate the total price in cents
    amount = cart.sum { |item| (item[:price] * 100).to_i * item[:quantity] }

    # Create a Stripe Payment Intent
    payment_intent = Stripe::PaymentIntent.create({
      amount: amount,      # Total price in cents
      currency: 'usd',     # Currency
      metadata: {
        # Optionally pass cart details to store additional information with the payment intent
        user_id: current_user.id, # Optional user tracking
      },
    })

    # Respond with the payment intent's client_secret (used on frontend)
    render json: { client_secret: payment_intent.client_secret }
  end
end

