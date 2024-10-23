require 'stripe'

class Api::PaymentsController < ApplicationController
  # before_action :authenticate_user!

  STRIPE_API_KEY = 'sk_test_51Q9rdFKtclhwv0vlAZIfMiBATbFSnHTOOGN7qemvPUeFyn6lKAEFyuiSnotPId8EIF9o0bICY5JrVY39gTK4qvAt00ksBff9a6'

  def create_payment_intent
    # Set the Stripe API key
    Stripe.api_key = STRIPE_API_KEY

    begin
      # Extract parameters directly from params
      currency = params[:currency]
      description = params[:description]
      products = params[:products] || []

      # Check if currency and products are present
      if currency.nil? || products.empty?
        return render json: { success: false, error: "Currency and products are required." }, status: :unprocessable_entity
      end

      # Calculate total amount from products
      total_amount = products.reduce(0) do |sum, product|
        price = product[:price].to_i
        quantity = product[:quantity].to_i
        sum + (price * quantity)
      end

      # Create the payment intent
      payment_intent = Stripe::PaymentIntent.create({
        amount: total_amount,
        currency: currency,
        description: description
      })

      # Return the payment intent details
      render json: { success: true, payment_intent: payment_intent }, status: :created
    rescue Stripe::StripeError => e
      render json: { success: false, error: e.message }, status: :unprocessable_entity
    rescue StandardError => e
      render json: { success: false, error: e.message }, status: :internal_server_error
    end
  end

  private

  def payment_intent_params
    # Ensure this method is not being used, as we're extracting directly
    params.permit(:currency, :description, products: [:price, :quantity])
  end
end
