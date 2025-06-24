require 'net/http'
require 'uri'
require 'json'

class PaypalService
  attr_reader :base_url, :client_id, :client_secret, :webhook_id

  def initialize
    @base_url = if Rails.env.production?
                  'https://api.paypal.com'
                else
                  'https://api.sandbox.paypal.com'
                end

    # Use environment-specific credentials
    if Rails.env.production?
      @client_id = Rails.application.credentials.paypal&.dig(:client_id) || ENV.fetch('PAYPAL_CLIENT_ID', nil)
      @client_secret = Rails.application.credentials.paypal&.dig(:client_secret) || ENV.fetch('PAYPAL_CLIENT_SECRET',
                                                                                              nil)
      @webhook_id = Rails.application.credentials.paypal&.dig(:webhook_id) || ENV.fetch('PAYPAL_WEBHOOK_ID', nil)
    else
      @client_id = Rails.application.credentials.paypal&.dig(:development_client_id) || ENV.fetch(
        'PAYPAL_DEVELOPMENT_CLIENT_ID', nil
      )
      @client_secret = Rails.application.credentials.paypal&.dig(:development_client_secret) || ENV.fetch(
        'PAYPAL_DEVELOPMENT_CLIENT_SECRET', nil
      )
      @webhook_id = Rails.application.credentials.paypal&.dig(:development_webhook_id) || ENV.fetch(
        'PAYPAL_DEVELOPMENT_WEBHOOK_ID', nil
      )
    end

    raise 'PayPal credentials not configured' if @client_id.blank? || @client_secret.blank?
  end

  def create_order(amount:, currency: 'USD', reference_id: nil, description: 'RavenBoost Order', user: nil)
    access_token = get_access_token
    return PaypalOrderResult.new(false, nil, 'Failed to get access token') unless access_token

    # Use user's currency if available, fallback to provided currency
    final_currency = user&.user_currency || currency
    locale = user&.paypal_locale || 'en-US'

    # Ensure currency is uppercase (PayPal requirement)
    final_currency = final_currency.upcase

    order_data = {
      intent: 'CAPTURE',
      purchase_units: [{
        reference_id: reference_id,
        description: description,
        amount: {
          currency_code: final_currency,
          value: format('%.2f', amount)
        }
      }],
      application_context: {
        return_url: build_return_url,
        cancel_url: build_cancel_url,
        brand_name: 'RavenBoost',
        landing_page: 'NO_PREFERENCE',
        user_action: 'PAY_NOW',
        locale: locale,
        shipping_preference: 'NO_SHIPPING'
      }
    }

    # Add payer information if user is provided
    order_data[:payer] = build_payer_info(user) if user.present?

    # Debug logging for PayPal order creation
    Rails.logger.info '=== PayPal Order Creation Debug ==='
    Rails.logger.info "Final Currency: #{final_currency}"
    Rails.logger.info "Amount: #{amount} -> Formatted: #{format('%.2f', amount)}"
    Rails.logger.info "Locale: #{locale}"
    Rails.logger.info "Order Data: #{order_data.to_json}"

    response = make_request(
      method: 'POST',
      endpoint: '/v2/checkout/orders',
      data: order_data,
      access_token: access_token
    )

    if response.success?
      order_id = response.parsed_body['id']
      PaypalOrderResult.new(true, order_id, nil)
    else
      Rails.logger.error "PayPal order creation failed: #{response.error_message}"
      PaypalOrderResult.new(false, nil, response.error_message)
    end
  end

  def capture_order(order_id)
    access_token = get_access_token
    return PaypalCaptureResult.new(false, nil, 'Failed to get access token') unless access_token

    response = make_request(
      method: 'POST',
      endpoint: "/v2/checkout/orders/#{order_id}/capture",
      data: {},
      access_token: access_token
    )

    if response.success?
      PaypalCaptureResult.new(true, response.parsed_body, nil)
    else
      PaypalCaptureResult.new(false, nil, response.error_message)
    end
  end

  def get_order(order_id)
    access_token = get_access_token
    return nil unless access_token

    response = make_request(
      method: 'GET',
      endpoint: "/v2/checkout/orders/#{order_id}",
      access_token: access_token
    )

    response.success? ? response.parsed_body : nil
  end

  def verify_webhook(headers, body)
    # Extract required headers
    transmission_id = headers['PAYPAL-TRANSMISSION-ID']
    cert_id = headers['PAYPAL-CERT-ID']
    signature = headers['PAYPAL-TRANSMISSION-SIG']
    timestamp = headers['PAYPAL-TRANSMISSION-TIME']

    # In development, do basic validation and log for debugging
    if Rails.env.development?
      Rails.logger.info '=== PayPal Webhook Verification (Development) ==='
      Rails.logger.info "Transmission ID: #{transmission_id}"
      Rails.logger.info "Cert ID: #{cert_id}"
      Rails.logger.info "Signature: #{signature}"
      Rails.logger.info "Timestamp: #{timestamp}"
      Rails.logger.info "Webhook ID: #{@webhook_id}"

      # Basic validation - ensure required headers are present
      return transmission_id.present? && cert_id.present? && signature.present? && timestamp.present?
    end

    # Production webhook verification using PayPal's verification service
    return false unless transmission_id && cert_id && signature && timestamp && @webhook_id

    access_token = get_access_token
    return false unless access_token

    verification_data = {
      auth_algo: 'SHA256withRSA',
      cert_id: cert_id,
      transmission_id: transmission_id,
      transmission_sig: signature,
      transmission_time: timestamp,
      webhook_id: @webhook_id,
      webhook_event: JSON.parse(body)
    }

    response = make_request(
      method: 'POST',
      endpoint: '/v1/notifications/verify-webhook-signature',
      data: verification_data,
      access_token: access_token
    )

    response.success? && response.parsed_body['verification_status'] == 'SUCCESS'
  rescue StandardError => e
    Rails.logger.error "Webhook verification failed: #{e.message}"
    false
  end

  # Verify if an email address is associated with a valid PayPal account
  def verify_paypal_email(email)
    access_token = get_access_token
    return PaypalEmailVerificationResult.new(false, 'Failed to get access token') unless access_token

    # Use PayPal's test payout approach - most reliable method
    verification_result = verify_email_with_test_payout(email, access_token)

    if verification_result[:success]
      PaypalEmailVerificationResult.new(true, 'Email verified successfully', verification_result[:batch_id])
    else
      PaypalEmailVerificationResult.new(false, verification_result[:error])
    end
  rescue StandardError => e
    Rails.logger.error "PayPal email verification failed: #{e.message}"
    PaypalEmailVerificationResult.new(false, "Verification failed: #{e.message}")
  end

  # Create a payout to send money to contractors
  def create_payout(recipient_email:, amount:, currency: 'USD', note: 'Payment from RavenBoost', sender_item_id: nil)
    access_token = get_access_token
    return PaypalPayoutResult.new(false, nil, nil, 'Failed to get access token') unless access_token

    payout_data = {
      sender_batch_header: {
        sender_batch_id: sender_item_id || "batch_#{SecureRandom.hex(8)}",
        email_subject: 'You have a payment from RavenBoost',
        email_message: 'Thank you for your work with RavenBoost. Your payment has been processed.'
      },
      items: [
        {
          recipient_type: 'EMAIL',
          amount: {
            value: format('%.2f', amount),
            currency: currency.upcase
          },
          receiver: recipient_email,
          note: note,
          sender_item_id: sender_item_id || "item_#{SecureRandom.hex(6)}"
        }
      ]
    }

    Rails.logger.info "Creating PayPal payout: #{amount} #{currency} to #{recipient_email}"

    response = make_request(
      method: 'POST',
      endpoint: '/v1/payments/payouts',
      data: payout_data,
      access_token: access_token
    )

    if response.success?
      parsed_response = response.parsed_body
      batch_id = parsed_response.dig('batch_header', 'payout_batch_id')
      item_id = parsed_response.dig('items', 0, 'payout_item_id')

      Rails.logger.info "PayPal payout created successfully: Batch #{batch_id}, Item #{item_id}"
      PaypalPayoutResult.new(true, batch_id, item_id, nil)
    else
      error_message = response.error_message
      Rails.logger.error "PayPal payout failed: #{error_message}"
      PaypalPayoutResult.new(false, nil, nil, error_message)
    end
  rescue StandardError => e
    Rails.logger.error "PayPal payout creation failed: #{e.message}"
    PaypalPayoutResult.new(false, nil, nil, "Payout creation failed: #{e.message}")
  end

  # Get payout status (class method for admin use)
  def self.get_payout_status(batch_id, item_id = nil)
    service = new
    service.get_payout_status_details(batch_id, item_id)
  end

  # Get detailed payout status information
  def get_payout_status_details(batch_id, item_id = nil)
    access_token = get_access_token
    return { success: false, error: 'Failed to get access token' } unless access_token

    url = if item_id.present?
      "/v1/payments/payouts-item/#{item_id}"
    else
      "/v1/payments/payouts/#{batch_id}"
    end

    response = make_request(
      method: 'GET',
      endpoint: url,
      access_token: access_token
    )

    if response.success?
      result = response.parsed_body

      status = if item_id.present?
        result['transaction_status']&.downcase
      else
        result.dig('batch_header', 'batch_status')&.downcase
      end

      {
        success: true,
        status: status,
        response: result,
        batch_id: batch_id,
        item_id: item_id
      }
    else
      {
        success: false,
        error: response.error_message,
        batch_id: batch_id,
        item_id: item_id
      }
    end
  rescue StandardError => e
    Rails.logger.error "PayPal status check failed: #{e.message}"
    {
      success: false,
      error: e.message,
      batch_id: batch_id,
      item_id: item_id
    }
  end

  # Get detailed payout information including all items
  def self.get_payout_details(batch_id)
    service = new
    service.get_payout_batch_details(batch_id)
  end

  def get_payout_batch_details(batch_id)
    access_token = get_access_token
    return { success: false, error: 'Failed to get access token' } unless access_token

    response = make_request(
      method: 'GET',
      endpoint: "/v1/payments/payouts/#{batch_id}",
      access_token: access_token
    )

    if response.success?
      result = response.parsed_body

      {
        success: true,
        batch_header: result['batch_header'],
        items: result['items'] || []
      }
    else
      {
        success: false,
        error: response.error_message
      }
    end
  rescue StandardError => e
    Rails.logger.error "PayPal payout details failed: #{e.message}"
    { success: false, error: e.message }
  end

  private

  # Verify email by creating a minimal test payout
  def verify_email_with_test_payout(email, access_token)
    # Create a test payout with $0.01 - will fail gracefully if email is invalid
    payout_data = {
      sender_batch_header: {
        sender_batch_id: "verify_#{SecureRandom.hex(8)}",
        email_subject: 'PayPal Email Verification - RavenBoost',
        email_message: 'This is a verification test for your PayPal email address.'
      },
      items: [
        {
          recipient_type: 'EMAIL',
          amount: {
            value: '0.01',
            currency: 'USD'
          },
          receiver: email,
          note: 'Email verification test - minimal amount',
          sender_item_id: "verify_#{SecureRandom.hex(4)}"
        }
      ]
    }

    response = make_request(
      method: 'POST',
      endpoint: '/v1/payments/payouts',
      data: payout_data,
      access_token: access_token
    )

    if response.success?
      parsed_response = response.parsed_body
      batch_id = parsed_response.dig('batch_header', 'payout_batch_id')

      Rails.logger.info "PayPal email verification payout created: #{batch_id} for #{email}"

      # Check the payout status immediately
      payout_status = get_payout_status(batch_id, access_token)

      if payout_status[:valid_email]
        { success: true, batch_id: batch_id, message: 'Email verified successfully' }
      else
        { success: false, error: payout_status[:error] || 'Email verification failed' }
      end
    else
      error_details = response.parsed_body
      error_message = error_details.dig('details', 0, 'description') ||
                      error_details['message'] ||
                      'Email verification failed'

      Rails.logger.warn "PayPal email verification failed for #{email}: #{error_message}"
      { success: false, error: error_message }
    end
  end

  # Check the status of a payout to determine if email is valid
  def get_payout_status(batch_id, access_token)
    response = make_request(
      method: 'GET',
      endpoint: "/v1/payments/payouts/#{batch_id}",
      access_token: access_token
    )

    if response.success?
      payout_details = response.parsed_body

      # Check individual items for specific errors
      items = payout_details['items'] || []
      first_item = items.first

      if first_item
        item_status = first_item['transaction_status']

        case item_status
        when 'SUCCESS', 'PENDING', 'UNCLAIMED'
          # Email is valid - payout was accepted
          { valid_email: true }
        when 'FAILED'
          # Check the failure reason
          error_code = first_item.dig('errors', 0, 'name')
          error_message = first_item.dig('errors', 0, 'message')

          if error_code == 'RECEIVER_UNREGISTERED'
            { valid_email: false, error: 'PayPal account not found for this email address' }
          else
            { valid_email: false, error: error_message || 'Email verification failed' }
          end
        else
          { valid_email: false, error: 'Unable to verify email address' }
        end
      else
        { valid_email: false, error: 'No payout items found' }
      end
    else
      { valid_email: false, error: 'Unable to check payout status' }
    end
  rescue StandardError => e
    Rails.logger.error "Error checking payout status: #{e.message}"
    { valid_email: false, error: 'Status check failed' }
  end

  def get_access_token
    auth_string = Base64.strict_encode64("#{@client_id}:#{@client_secret}")

    uri = URI("#{@base_url}/v1/oauth2/token")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Basic #{auth_string}"
    request['Content-Type'] = 'application/x-www-form-urlencoded'
    request.body = 'grant_type=client_credentials'

    response = http.request(request)

    if response.code == '200'
      JSON.parse(response.body)['access_token']
    else
      Rails.logger.error "PayPal auth failed: #{response.body}"
      nil
    end
  rescue StandardError => e
    Rails.logger.error "PayPal authentication error: #{e.message}"
    nil
  end

  def make_request(method:, endpoint:, access_token:, data: nil)
    uri = URI("#{@base_url}#{endpoint}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    case method.upcase
    when 'GET'
      request = Net::HTTP::Get.new(uri)
    when 'POST'
      request = Net::HTTP::Post.new(uri)
      request.body = data.to_json if data
    when 'PUT'
      request = Net::HTTP::Put.new(uri)
      request.body = data.to_json if data
    else
      raise "Unsupported HTTP method: #{method}"
    end

    request['Authorization'] = "Bearer #{access_token}"
    request['Content-Type'] = 'application/json'
    request['Accept'] = 'application/json'

    response = http.request(request)
    PaypalResponse.new(response)
  rescue StandardError => e
    Rails.logger.error "PayPal API request failed: #{e.message}"
    PaypalResponse.new(OpenStruct.new(code: '500', body: { error: e.message }.to_json))
  end

  def build_return_url
    # Configure based on your frontend URL
    if Rails.env.production?
      'https://your-domain.com/payment/success'
    else
      'http://localhost:3001/checkout/success' # Frontend development port
    end
  end

  def build_cancel_url
    # Configure based on your frontend URL
    if Rails.env.production?
      'https://your-domain.com/payment/cancel'
    else
      'http://localhost:3001/checkout/cancel' # Frontend development port
    end
  end

  def build_payer_info(user)
    {
      email_address: user.email,
      name: {
        given_name: user.first_name || 'Customer',
        surname: user.last_name || 'User'
      }
    }
  end
end

# Result classes
class PaypalEmailVerificationResult
  attr_reader :success, :message, :batch_id

  def initialize(success, message, batch_id = nil)
    @success = success
    @message = message
    @batch_id = batch_id
  end

  def successful?
    @success
  end

  def error_message
    @success ? nil : @message
  end
end

class PaypalOrderResult
  attr_reader :success, :id, :error_message

  def initialize(success, id, error_message)
    @success = success
    @id = id
    @error_message = error_message
  end

  def successful?
    @success
  end
end

class PaypalCaptureResult
  attr_reader :success, :data, :error_message

  def initialize(success, data, error_message)
    @success = success
    @data = data
    @error_message = error_message
  end

  def successful?
    @success
  end
end

class PaypalPayoutResult
  attr_reader :success, :batch_id, :item_id, :error_message

  def initialize(success, batch_id, item_id, error_message)
    @success = success
    @batch_id = batch_id
    @item_id = item_id
    @error_message = error_message
  end

  def successful?
    @success
  end

  def error_message
    @success ? nil : @error_message
  end
end

class PaypalResponse
  attr_reader :response

  def initialize(response)
    @response = response
  end

  def success?
    @response.code.to_i.between?(200, 299)
  end

  def parsed_body
    @parsed_body ||= JSON.parse(@response.body)
  rescue JSON::ParserError
    {}
  end

  def error_message
    if success?
      nil
    else
      # Enhanced error logging for debugging
      Rails.logger.error '=== PayPal API Error Debug ==='
      Rails.logger.error "Response Code: #{@response.code}"
      Rails.logger.error "Response Body: #{@response.body}"
      Rails.logger.error "Parsed Body: #{parsed_body}"

      parsed_body.dig('details', 0, 'description') ||
        parsed_body['message'] ||
        "HTTP #{@response.code}: #{@response.message}"
    end
  end
end
