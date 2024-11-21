require 'stripe'

class Api::PaymentsController < ApplicationController
  before_action :authenticate_user!

  USE_DEV_CREDENTIALS = false # Set this to `false` for production

  if USE_DEV_CREDENTIALS
    STRIPE_API_KEY = 'sk_test_51Q9rdFKtclhwv0vlAZIfMiBATbFSnHTOOGN7qemvPUeFyn6lKAEFyuiSnotPId8EIF9o0bICY5JrVY39gTK4qvAt00ksBff9a6'
    DOMAIN_URL = 'localhost:3001'
  else
    STRIPE_API_KEY = Rails.application.credentials.stripe[:secret_key]
    DOMAIN_URL = Rails.application.credentials.domain_url
  end

  if STRIPE_API_KEY.nil?
    Rails.logger.info('Stripe API Key not found. Please set STRIPE_API_KEY environment variable.')
  else
    Rails.logger.info('API Key Loaded')
  end

  def create_checkout_session
    # Set the Stripe API key
    Stripe.api_key = STRIPE_API_KEY

    begin
      # Extract parameters directly from params
      currency = params[:currency]
      products = params[:products] || []
      promotion = params[:promotion]

      # Check if currency and products are present
      if currency.nil? || products.empty?
        return render json: { success: false, error: 'Currency and products are required.' },
                      status: :unprocessable_entity
      end

      # Create line items for the checkout session
      line_items = products.map do |product|
        image_url = product[:image] && !product[:image].match?(/\.webp$/) ? product[:image] : 'https://www.ravenboost.com/logo.svg'

        {
          price_data: {
            currency: currency,
            product_data: {
              name: product[:name] || 'Product Name',
              images: [image_url]
            },
            unit_amount: ((product[:price].to_f + product[:tax].to_f) * 100).to_i
          },
          quantity: product[:quantity].to_i
        }
      end

      discounts = []
      if promotion.present? && promotion[:discount_percentage].to_f.positive?
        discounts << {
          coupon: find_or_create_coupon_for_discount(promotion)
        }
      end

      # Create the checkout session
      session = Stripe::Checkout::Session.create({
                                                   payment_method_types: ['card'],
                                                   line_items: line_items,
                                                   mode: 'payment',
                                                   customer_email: current_user.email,
                                                   success_url: "https://#{DOMAIN_URL}/checkout/success?session_id={CHECKOUT_SESSION_ID}",
                                                   cancel_url: "https://#{DOMAIN_URL}/checkout",
                                                   discounts: discounts
                                                 })

      # Return the session ID (which can be used to redirect the customer)
      render json: { success: true, sessionId: session.id }, status: :created
    rescue Stripe::StripeError => e
      render json: { success: false, error: e.message }, status: :unprocessable_entity
    rescue StandardError => e
      render json: { success: false, error: e.message }, status: :internal_server_error
    end
  end

  def find_or_create_coupon_for_discount(promotion)
    # Check if the coupon already exists by ID or code (depending on your preference)
    existing_coupon = Stripe::Coupon.list(limit: 100).data.find { |coupon| coupon.id == promotion[:code] }

    if existing_coupon
      # If the coupon exists, return its ID
      existing_coupon.id
    else
      # If the coupon doesn't exist, create a new one
      coupon = Stripe::Coupon.create(
        percent_off: promotion[:discount_percentage].to_f,
        currency: 'usd',
        duration: 'once',
        id: promotion[:code]
      )
      coupon.id
    end
  end

  # Optionally, you can add a method to retrieve the session status
  def session_status
    session = Stripe::Checkout::Session.retrieve(params[:session_id])
    render json: { status: session.status, customer_email: session.customer_email }, status: :ok
  rescue Stripe::StripeError => e
    render json: { success: false, error: e.message }, status: :unprocessable_entity
  end
end
