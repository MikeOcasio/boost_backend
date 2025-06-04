require 'stripe'

class Api::PaymentsController < ApplicationController
  before_action :authenticate_user!

  STRIPE_API_KEY = Rails.application.credentials.stripe[:secret_key]

  if STRIPE_API_KEY.nil?
    Rails.logger.info('Stripe API Key not found. Please set STRIPE_API_KEY environment variable.')
  else
    Rails.logger.info('API Key Loaded')
  end

  def webhook
    # Handle Stripe webhooks for payment completion
    Stripe.api_key = STRIPE_API_KEY

    begin
      sig_header = request.headers['Stripe-Signature']
      event = nil

      # Verify webhook signature (you should set this in Rails credentials)
      endpoint_secret = Rails.application.credentials.stripe[:webhook_secret]

      event = if endpoint_secret
                Stripe::Webhook.construct_event(
                  request.body.read,
                  sig_header,
                  endpoint_secret
                )
              else
                JSON.parse(request.body.read, symbolize_names: true)
              end

      case event[:type]
      when 'checkout.session.completed'
        handle_checkout_completed(event[:data][:object])
      when 'payment_intent.succeeded'
        handle_payment_succeeded(event[:data][:object])
      end

      render json: { received: true }, status: :ok
    rescue JSON::ParserError
      render json: { error: 'Invalid payload' }, status: :bad_request
    rescue Stripe::SignatureVerificationError
      render json: { error: 'Invalid signature' }, status: :bad_request
    end
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

      # Create order first
      order = Order.create!(
        user: current_user,
        total_price: calculate_total_price(products, promotion),
        state: 'open'
      )

      # Add products to order
      products.each do |product_data|
        # Only create order_product if the product exists
        next unless Product.exists?(product_data[:id])

        order.order_products.create!(
          product_id: product_data[:id],
          quantity: product_data[:quantity],
          price: product_data[:price]
        )
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

      # Create the checkout session with payment_intent_data to capture manually
      session = Stripe::Checkout::Session.create({
                                                   payment_method_types: ['card'],
                                                   line_items: line_items,
                                                   mode: 'payment',
                                                   customer_email: current_user.email,
                                                   success_url: "https://www.ravenboost.com/checkout/success?session_id={CHECKOUT_SESSION_ID}&order_id=#{order.id}",
                                                   cancel_url: 'https://www.ravenboost.com/checkout',
                                                   discounts: discounts,
                                                   payment_intent_data: {
                                                     capture_method: 'manual', # Hold the payment
                                                     metadata: { order_id: order.id }
                                                   },
                                                   metadata: { order_id: order.id }
                                                 })

      # Store session ID in order
      order.update!(stripe_session_id: session.id)

      # Return the session ID (which can be used to redirect the customer)
      render json: { success: true, sessionId: session.id, order_id: order.id }, status: :created
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

  def create_payment_intent
    Stripe.api_key = STRIPE_API_KEY

    begin
      # Extract parameters
      amount = params[:amount].to_f * 100 # Convert to cents
      currency = params[:currency] || 'usd'
      order_id = params[:order_id]

      # Validate required parameters
      if amount <= 0 || order_id.blank?
        return render json: {
          success: false,
          error: 'Amount and order_id are required.'
        }, status: :unprocessable_entity
      end

      # Find the order
      order = Order.find(order_id)
      unless order.user == current_user
        return render json: {
          success: false,
          error: 'Unauthorized'
        }, status: :forbidden
      end

      # Create payment intent with manual capture
      payment_intent = Stripe::PaymentIntent.create({
                                                      amount: amount.to_i,
                                                      currency: currency,
                                                      customer: find_or_create_stripe_customer(current_user),
                                                      metadata: {
                                                        order_id: order.id,
                                                        user_id: current_user.id
                                                      },
                                                      capture_method: 'manual' # This holds the payment
                                                    })

      # Store payment intent ID in order
      order.update!(stripe_payment_intent_id: payment_intent.id)

      render json: {
        success: true,
        client_secret: payment_intent.client_secret,
        payment_intent_id: payment_intent.id
      }, status: :created
    rescue Stripe::StripeError => e
      render json: { success: false, error: e.message }, status: :unprocessable_entity
    rescue StandardError => e
      render json: { success: false, error: e.message }, status: :internal_server_error
    end
  end

  def complete_payment
    Stripe.api_key = STRIPE_API_KEY

    begin
      order_id = params[:order_id]
      order = Order.find(order_id)

      # Verify order is complete and has a payment intent
      unless order.complete? && order.stripe_payment_intent_id.present?
        return render json: {
          success: false,
          error: 'Order is not complete or has no payment intent'
        }, status: :unprocessable_entity
      end

      # Capture the payment
      payment_intent = Stripe::PaymentIntent.capture(order.stripe_payment_intent_id)

      # Calculate split amounts (75% to skillmaster, 25% to company)
      total_amount = payment_intent.amount / 100.0 # Convert from cents
      skillmaster_amount = total_amount * 0.60
      company_amount = total_amount * 0.40

      # Find skillmaster's contractor record
      skillmaster = User.find(order.assigned_skill_master_id)
      contractor = skillmaster.contractor

      if contractor.nil?
        return render json: {
          success: false,
          error: 'Skillmaster has no contractor account'
        }, status: :unprocessable_entity
      end

      # Add to skillmaster's pending balance
      contractor.add_to_pending_balance(skillmaster_amount)

      # Update order with payment completion
      order.update!(
        payment_captured_at: Time.current,
        skillmaster_earned: skillmaster_amount,
        company_earned: company_amount
      )

      render json: {
        success: true,
        message: 'Payment captured and split successfully',
        skillmaster_earned: skillmaster_amount,
        company_earned: company_amount
      }, status: :ok
    rescue Stripe::StripeError => e
      render json: { success: false, error: e.message }, status: :unprocessable_entity
    rescue StandardError => e
      render json: { success: false, error: e.message }, status: :internal_server_error
    end
  end

  private

  def handle_checkout_completed(session)
    order = Order.find_by(stripe_session_id: session[:id])
    return unless order

    # Get the payment intent from the session
    payment_intent = Stripe::PaymentIntent.retrieve(session[:payment_intent])
    order.update!(stripe_payment_intent_id: payment_intent.id)
  end

  def handle_payment_succeeded(payment_intent)
    order = Order.find_by(stripe_payment_intent_id: payment_intent[:id])
    return unless order

    # Payment succeeded but we don't capture until order is complete
    order.update!(payment_status: 'authorized')
  end

  def calculate_total_price(products, promotion)
    subtotal = products.sum { |p| (p[:price].to_f + p[:tax].to_f) * p[:quantity].to_i }

    if promotion.present? && promotion[:discount_percentage].to_f.positive?
      discount = subtotal * (promotion[:discount_percentage].to_f / 100)
      subtotal - discount
    else
      subtotal
    end
  end

  def find_or_create_stripe_customer(user)
    if user.stripe_customer_id.present?
      user.stripe_customer_id
    else
      customer = Stripe::Customer.create({
                                           email: user.email,
                                           name: "#{user.first_name} #{user.last_name}",
                                           metadata: { user_id: user.id }
                                         })
      user.update!(stripe_customer_id: customer.id)
      customer.id
    end
  end
end
