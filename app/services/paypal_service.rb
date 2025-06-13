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

  private

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
