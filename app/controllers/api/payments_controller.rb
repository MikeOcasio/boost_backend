require 'stripe'

class Api::PaymentsController < ApplicationController
  # before_action :authenticate_user!

  STRIPE_API_KEY = 'sk_test_51Q9rdFKtclhwv0vlAZIfMiBATbFSnHTOOGN7qemvPUeFyn6lKAEFyuiSnotPId8EIF9o0bICY5JrVY39gTK4qvAt00ksBff9a6'
  YOUR_DOMAIN = 'http://127.0.0.1:3001'

  def create_checkout_session
    # Set the Stripe API key
    Stripe.api_key = STRIPE_API_KEY

    begin
      # Extract parameters directly from params
      currency = params[:currency]
      products = params[:products] || []

      # Check if currency and products are present
      if currency.nil? || products.empty?
        return render json: { success: false, error: "Currency and products are required." }, status: :unprocessable_entity
      end

      # Create line items for the checkout session
      line_items = products.map do |product|
        {
          price_data: {
            currency: currency,
            product_data: {
              name: product[:name] || 'Product Name',
              images: 'https://images.pexels.com/photos/104827/cat-pet-animal-domestic-104827.jpeg?cs=srgb&amp;dl=pexels-pixabay-104827.jpg&amp;fm=jpg'
            },
            unit_amount: (product[:price].to_i * 100),
          },
          quantity: product[:quantity].to_i,
        }
      end

      # Create the checkout session
      session = Stripe::Checkout::Session.create({
        payment_method_types: ['card', 'paypal'],
        line_items: line_items,
        mode: 'payment',
        success_url: "#{YOUR_DOMAIN}/checkout/success",
        cancel_url: "#{YOUR_DOMAIN}/checkout",
      })

      # Return the session ID (which can be used to redirect the customer)
      render json: { success: true, sessionId: session.id }, status: :created
    rescue Stripe::StripeError => e
      render json: { success: false, error: e.message }, status: :unprocessable_entity
    rescue StandardError => e
      render json: { success: false, error: e.message }, status: :internal_server_error
    end
  end

  # Optionally, you can add a method to retrieve the session status
  def session_status
    begin
      session = Stripe::Checkout::Session.retrieve(params[:session_id])
      render json: { status: session.status, customer_email: session.customer_email }, status: :ok
    rescue Stripe::StripeError => e
      render json: { success: false, error: e.message }, status: :unprocessable_entity
    end
  end
end
