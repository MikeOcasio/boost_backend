require 'stripe'

class Api::PaymentsController < ApplicationController
  before_action :authenticate_user!

  STRIPE_API_KEY = Rails.application.credentials.stripe[:test_secret]

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
      promo_data = params[:promo_data]
      order_data = params[:order_data]

      # Check if currency and products are present
      if currency.nil? || products.empty?
        return render json: { success: false, error: 'Currency and products are required.' },
                      status: :unprocessable_entity
      end

      # Extract platform ID from the first product
      platform_id = products.first&.dig('platform', 'id') || products.first&.dig(:platform, :id)

      # Validate and normalize product data
      normalized_products = normalize_product_data(products)

      # Calculate total price for the session
      total_price = calculate_total_price(normalized_products, promotion)

      # Create line items for the checkout session
      line_items = normalized_products.map do |product|
        image_url = product[:image] && !product[:image].match?(/\.webp$/) ? product[:image] : 'https://www.ravenboost.com/logo.svg'

        {
          price_data: {
            currency: currency,
            product_data: {
              name: product[:name] || 'Product Name',
              images: [image_url]
            },
            unit_amount: ((product[:price] + product[:tax]) * 100).to_i
          },
          quantity: product[:quantity]
        }
      end

      discounts = []
      if promotion.present? && promotion[:discount_percentage].to_f.positive?
        discounts << {
          coupon: find_or_create_coupon_for_discount(promotion)
        }
      end

      # Store all order data in session metadata for order creation after payment
      session_metadata = {
        user_id: current_user.id,
        platform_id: platform_id,
        total_price: total_price,
        promo_data: promo_data ? promo_data.to_json : nil,
        order_data: order_data ? order_data.to_json : nil,
        products: normalized_products.to_json
      }.compact

      # Create the checkout session with payment_intent_data to capture manually
      session = Stripe::Checkout::Session.create({
                                                   payment_method_types: ['card'],
                                                   line_items: line_items,
                                                   mode: 'payment',
                                                   customer_email: current_user.email,
                                                   success_url: 'http://localhost:3001/checkout/success?session_id={CHECKOUT_SESSION_ID}',
                                                   cancel_url: 'http://localhost:3001/checkout',
                                                   discounts: discounts,
                                                   payment_intent_data: {
                                                     capture_method: 'manual', # Hold the payment
                                                     metadata: session_metadata
                                                   },
                                                   metadata: session_metadata
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

  # GET /api/payments/order_id_from_session
  # Retrieve order ID after successful payment using session ID
  def order_id_from_session
    Stripe.api_key = STRIPE_API_KEY

    begin
      session_id = params[:session_id]

      if session_id.blank?
        return render json: {
          success: false,
          error: 'Session ID is required.'
        }, status: :unprocessable_entity
      end

      # Retrieve the Stripe session
      session = Stripe::Checkout::Session.retrieve(session_id)

      # Log session details for debugging
      Rails.logger.info "Session details: payment_status=#{session.payment_status}, status=#{session.status}"

      # Check if payment was successful - Stripe uses different status fields
      # session.payment_status can be: 'paid', 'unpaid', 'no_payment_required'
      # session.status can be: 'open', 'complete', 'expired'
      #
      # According to Stripe docs, status=complete with payment_status=unpaid can be valid
      # when "the payment funds are not yet available in your account" but checkout is complete
      payment_successful = session.status == 'complete' || session.payment_status == 'paid'

      unless payment_successful
        Rails.logger.warn "Payment not successful: payment_status=#{session.payment_status}, status=#{session.status}"
        return render json: {
          success: false,
          error: 'Payment was not successful.',
          payment_status: session.payment_status,
          session_status: session.status
        }, status: :unprocessable_entity
      end

      # Find the order by session ID
      order = Order.find_by(stripe_session_id: session_id)

      if order.nil?
        Rails.logger.warn "Order not found for session: #{session_id}, attempting to create order from session"

        # Try to create the order if it doesn't exist
        # This handles cases where the frontend calls this endpoint before the webhook creates the order
        # Extract order data from session metadata as fallback
        session_metadata = session.metadata
        if session_metadata['user_id'].to_i == current_user.id
          platform_id = session_metadata['platform_id']
          total_price = session_metadata['total_price'].to_f
          promo_data = session_metadata['promo_data'] ? JSON.parse(session_metadata['promo_data']) : nil
          order_data = session_metadata['order_data'] ? JSON.parse(session_metadata['order_data']) : nil
          products = JSON.parse(session_metadata['products'])

          order = create_order(
            platform_id: platform_id,
            total_price: total_price,
            promo_data: promo_data,
            order_data: order_data,
            products: products,
            stripe_session_id: session_id,
            stripe_payment_intent_id: session.payment_intent
          )
        end

        if order.nil?
          Rails.logger.error "Failed to create order from session: #{session_id}"
          return render json: {
            success: false,
            error: 'Order not found for this session and could not be created.'
          }, status: :not_found
        end
      end

      # Verify the order belongs to the current user
      unless order.user_id == current_user.id
        Rails.logger.warn "Unauthorized access: user #{current_user.id} trying to access order #{order.id} belonging to user #{order.user_id}"
        return render json: {
          success: false,
          error: 'Unauthorized access to order.'
        }, status: :forbidden
      end

      Rails.logger.info "Successfully retrieved order #{order.id} for session #{session_id}"

      render json: {
        success: true,
        order_id: order.id,
        internal_id: order.internal_id,
        payment_status: session.payment_status,
        session_status: session.status,
        order_state: order.state
      }, status: :ok
    rescue Stripe::StripeError => e
      Rails.logger.error "Stripe error in order_id_from_session: #{e.message}"
      render json: {
        success: false,
        error: "Stripe error: #{e.message}"
      }, status: :unprocessable_entity
    rescue StandardError => e
      Rails.logger.error "Server error in order_id_from_session: #{e.message}"
      render json: {
        success: false,
        error: "Server error: #{e.message}"
      }, status: :internal_server_error
    end
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

  # NOTE: complete_payment method removed - payment capture is now handled
  # through admin approval workflow using CapturePaymentJob

  private

  # =============================================================================
  # WEBHOOK HANDLERS
  # =============================================================================

  def handle_checkout_completed(session)
    # Find order by session ID (order should exist now, created in checkout session process)
    order = Order.find_by(stripe_session_id: session[:id])

    # If order doesn't exist, try to create it using session metadata (fallback for edge cases)
    if order.nil?
      Rails.logger.warn "Order not found for session #{session[:id]} in webhook, attempting to create from metadata"

      # For webhook context, we need to retrieve the full session object and extract metadata
      begin
        full_session = Stripe::Checkout::Session.retrieve(session[:id])
        session_metadata = full_session.metadata

        if session_metadata['user_id'].present?
          user = User.find(session_metadata['user_id'])
          platform_id = session_metadata['platform_id']
          total_price = session_metadata['total_price'].to_f
          promo_data = session_metadata['promo_data'] ? JSON.parse(session_metadata['promo_data']) : nil
          order_data = session_metadata['order_data'] ? JSON.parse(session_metadata['order_data']) : nil
          products = JSON.parse(session_metadata['products'])

          order = create_order_for_user(
            user: user,
            platform_id: platform_id,
            total_price: total_price,
            promo_data: promo_data,
            order_data: order_data,
            products: products,
            stripe_session_id: session[:id],
            stripe_payment_intent_id: session[:payment_intent]
          )
        end
      rescue Stripe::StripeError => e
        Rails.logger.error "Failed to retrieve session #{session[:id]} for order creation: #{e.message}"
        return
      end

      return unless order
    end

    # Get the payment intent from the session and ensure it's stored
    return unless session[:payment_intent].present? && order.stripe_payment_intent_id.blank?

    order.update!(stripe_payment_intent_id: session[:payment_intent])
  end

  def handle_payment_succeeded(payment_intent)
    # Find order by payment intent ID
    order = Order.find_by(stripe_payment_intent_id: payment_intent[:id])
    return unless order

    # Payment succeeded but we don't capture until order is complete
    order.update!(payment_status: 'authorized')
  end

  def calculate_total_price(products, promotion)
    subtotal = products.sum { |p| (p[:price] + p[:tax]) * p[:quantity] }

    if promotion.present? && promotion[:discount_percentage].to_f.positive?
      discount = subtotal * (promotion[:discount_percentage].to_f / 100)
      subtotal - discount
    else
      subtotal
    end
  end

  # =============================================================================
  # PRODUCT DATA PROCESSING
  # =============================================================================

  def normalize_product_data(products)
    products.map do |product|
      # Convert string/symbol keys to symbols and normalize data types
      normalized = product.is_a?(Hash) ? product.with_indifferent_access : product

      {
        id: normalized[:id] || normalized['id'],
        name: normalized[:name] || normalized['name'] || 'Product Name',
        price: normalize_decimal_value(normalized[:price] || normalized['price'] || 0),
        tax: normalize_decimal_value(normalized[:tax] || normalized['tax'] || 0),
        quantity: normalize_integer_value(normalized[:quantity] || normalized['quantity'] || 1),
        image: normalized[:image] || normalized['image']
      }
    end
  end

  def normalize_decimal_value(value)
    return value.to_f if value.is_a?(String) || value.is_a?(Numeric)

    0.0
  end

  def normalize_integer_value(value)
    return value.to_i if value.is_a?(String) || value.is_a?(Numeric)

    1
  end

  # =============================================================================
  # STRIPE CUSTOMER MANAGEMENT
  # =============================================================================

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

  # =============================================================================
  # ORDER CREATION AND MANAGEMENT
  # =============================================================================

  # Single order creation method for current_user context
  # Creates an order from the provided data and optionally validates payment via session_id
  def create_order(platform_id:, total_price:, products:, promo_data: nil, order_data: nil, stripe_session_id: nil,
                   stripe_payment_intent_id: nil)
    create_order_for_user(
      user: current_user,
      platform_id: platform_id,
      total_price: total_price,
      products: products,
      promo_data: promo_data,
      order_data: order_data,
      stripe_session_id: stripe_session_id,
      stripe_payment_intent_id: stripe_payment_intent_id
    )
  end

  # Core order creation method that works with any user
  def create_order_for_user(user:, platform_id:, total_price:, products:, promo_data: nil, order_data: nil, stripe_session_id: nil,
                            stripe_payment_intent_id: nil)
    # Check if order already exists (double-check to avoid race conditions)
    if stripe_session_id.present?
      existing_order = Order.find_by(stripe_session_id: stripe_session_id)
      return existing_order if existing_order.present?
    end

    # Create the order
    order = Order.create!(
      user: user,
      total_price: total_price,
      state: 'open',
      platform: platform_id,
      promo_data: promo_data,
      order_data: order_data,
      stripe_session_id: stripe_session_id
    )

    # Assign platform credentials if platform is provided
    assign_platform_credential_to_order(order, platform_id, user)

    # Add products to order
    add_products_to_order(order, products)

    # Store the payment intent ID if available
    order.update!(stripe_payment_intent_id: stripe_payment_intent_id) if stripe_payment_intent_id.present?

    Rails.logger.info "Successfully created order #{order.id}"
    order
  rescue StandardError => e
    Rails.logger.error "Error creating order: #{e.message}"
    nil
  end

  # Helper method to assign platform credentials to an order
  def assign_platform_credential_to_order(order, platform_id, user = nil)
    return if platform_id.blank?

    target_user = user || current_user
    platform_credential = PlatformCredential.find_by(user_id: target_user.id, platform_id: platform_id)
    order.update!(platform_credential: platform_credential) if platform_credential
  end

  # Helper method to add products to an order
  def add_products_to_order(order, products)
    products.each do |product_data|
      # Only create order_product if the product exists
      next unless Product.exists?(product_data['id'])

      order.order_products.create!(
        product_id: product_data['id'],
        quantity: product_data['quantity'],
        price: product_data['price']
      )
    end
  end
end
