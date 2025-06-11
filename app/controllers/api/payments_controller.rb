class Api::PaymentsController < ApplicationController
  before_action :authenticate_user!

  def webhook
    # Handle PayPal webhooks for payment completion

    # Verify PayPal webhook signature
    unless verify_paypal_webhook(request)
      render json: { error: 'Invalid signature' }, status: :bad_request
      return
    end

    event_data = JSON.parse(request.body.read, symbolize_names: true)

    case event_data[:event_type]
    when 'CHECKOUT.ORDER.APPROVED'
      handle_order_approved(event_data[:resource])
    when 'PAYMENT.CAPTURE.COMPLETED'
      handle_payment_captured(event_data[:resource])
    when 'PAYMENT.CAPTURE.DENIED'
      handle_payment_failed(event_data[:resource])
    end

    render json: { received: true }, status: :ok
  rescue JSON::ParserError
    render json: { error: 'Invalid payload' }, status: :bad_request
  rescue StandardError => e
    Rails.logger.error "PayPal webhook error: #{e.message}"
    render json: { error: 'Webhook processing failed' }, status: :internal_server_error
  end

  def create_paypal_order
    # Extract parameters
    currency = params[:currency] || 'USD'
    products = JSON.parse(params[:products] || '[]')
    promotion = params[:promotion]
    promo_data = params[:promo_data]
    order_data = params[:order_data]

    # Validate required parameters
    if products.empty?
      return render json: { success: false, error: 'Products are required.' },
                    status: :unprocessable_entity
    end

    # Extract platform ID from the first product
    platform_id = products.first&.dig('platform', 'id') || products.first&.dig(:platform, :id)

    # Validate and normalize product data
    normalized_products = normalize_product_data(products)

    # Calculate total price for the order
    total_price = calculate_total_price(normalized_products, promotion)

    # Create PayPal order
    paypal_service = PaypalService.new
    paypal_order = paypal_service.create_order(
      amount: total_price,
      currency: currency,
      reference_id: "order_#{SecureRandom.hex(5)}",
      description: build_order_description(normalized_products)
    )

    if paypal_order.successful?
      # Store order data in session for later order creation
      session[:pending_order_data] = {
        user_id: current_user.id,
        platform_id: platform_id,
        total_price: total_price,
        promo_data: promo_data,
        order_data: order_data,
        products: normalized_products.to_json,
        paypal_order_id: paypal_order.id
      }

      render json: {
        success: true,
        order_id: paypal_order.id,
        approval_url: build_paypal_approval_url(paypal_order.id)
      }
    else
      render json: {
        error: 'Failed to create PayPal order',
        message: paypal_order.error_message
      }, status: :unprocessable_entity
    end
  rescue StandardError => e
    render json: { success: false, error: e.message }, status: :internal_server_error
  end

  def approve_paypal_order
    order_id = params[:order_id]

    # Create order in our system using session data
    pending_data = session[:pending_order_data]

    if pending_data.nil? || pending_data['paypal_order_id'] != order_id
      return render json: { error: 'Invalid order session' }, status: :bad_request
    end

    # Create the order in our database
    order = create_order_from_session_data(pending_data)

    if order
      # Clear session data
      session.delete(:pending_order_data)

      render json: {
        success: true,
        order_id: order.id,
        internal_id: order.internal_id
      }
    else
      render json: { error: 'Failed to create order' }, status: :unprocessable_entity
    end
  rescue StandardError => e
    render json: { error: e.message }, status: :internal_server_error
  end

  def capture_payment
    # Admin endpoint to capture payment after approval

    order_id = params[:order_id]
    order = Order.find(order_id)

    # Verify order can be captured
    unless order.payment_approval&.approved?
      return render json: { error: 'Payment not approved by admin' }, status: :forbidden
    end

    # Queue payment capture job
    CapturePaypalPaymentJob.perform_later(order.id)

    render json: { success: true, message: 'Payment capture initiated' }
  rescue StandardError => e
    render json: { error: e.message }, status: :internal_server_error
  end

  private

  def verify_paypal_webhook(request)
    # Implement PayPal webhook signature verification
    # Get the webhook signature from headers
    paypal_transmission_id = request.headers['PAYPAL-TRANSMISSION-ID']
    paypal_transmission_sig = request.headers['PAYPAL-TRANSMISSION-SIG']

    # In production, implement proper webhook verification using PayPal's SDK
    # For now, check if basic headers are present
    return true if Rails.env.development? && paypal_transmission_id.present?

    # TODO: Implement full webhook verification with PayPal's verification API
    # This should verify the signature using PayPal's public key
    webhook_id = Rails.application.credentials.paypal&.dig(:webhook_id) || ENV.fetch('PAYPAL_WEBHOOK_ID', nil)

    return false unless webhook_id && paypal_transmission_sig.present?

    # Placeholder for actual verification - should use PayPal SDK
    true
  end

  def handle_order_approved(resource)
    # Handle when customer approves PayPal order
    order = Order.find_by(paypal_order_id: resource[:id])
    return unless order

    order.update!(paypal_payment_status: 'approved')
    Rails.logger.info "PayPal order approved: #{resource[:id]}"
  end

  def handle_payment_captured(resource)
    # Handle successful payment capture
    order = Order.find_by(paypal_capture_id: resource[:id])
    return unless order

    order.update!(paypal_payment_status: 'captured')
    Rails.logger.info "PayPal payment captured: #{resource[:id]}"
  end

  def handle_payment_failed(resource)
    # Handle failed payment capture
    order = Order.find_by(paypal_order_id: resource[:supplementary_data][:related_ids][:order_id])
    return unless order

    order.update!(paypal_payment_status: 'failed')
    Rails.logger.error "PayPal payment failed: #{resource[:id]}"
  end

  def build_paypal_approval_url(order_id)
    if Rails.env.production?
      "https://www.paypal.com/checkoutnow?token=#{order_id}"
    else
      "https://www.sandbox.paypal.com/checkoutnow?token=#{order_id}"
    end
  end

  def build_order_description(products)
    "RavenBoost Order - #{products.map { |p| p[:name] }.join(', ')}"
  end

  def create_order_from_session_data(data)
    products = JSON.parse(data['products'])

    order = Order.create!(
      user_id: data['user_id'],
      total_price: data['total_price'],
      state: 'open',
      platform: data['platform_id'],
      promo_data: data['promo_data'],
      order_data: data['order_data'],
      paypal_order_id: data['paypal_order_id'],
      paypal_payment_status: 'created'
    )

    # Add products to order
    products.each do |product_data|
      next unless Product.exists?(product_data['id'])

      order.order_products.create!(
        product_id: product_data['id'],
        quantity: product_data['quantity'],
        price: product_data['price']
      )
    end

    order
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

  def normalize_product_data(products)
    products.map do |product|
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
end
