require 'net/http'
require 'uri'
require 'json'

class PaypalService
  include PayPal::Payments

  def initialize
    validate_credentials!

    @environment = if Rails.env.production?
                     PayPal::Environment::Live.new(
                       Rails.application.credentials.paypal[:client_id],
                       Rails.application.credentials.paypal[:client_secret]
                     )
                   else
                     # Use development credentials for testing (not sandbox)
                     PayPal::Environment::Sandbox.new(
                       Rails.application.credentials.paypal[:development_client_id] || ENV['PAYPAL_DEVELOPMENT_CLIENT_ID'],
                       Rails.application.credentials.paypal[:development_client_secret] || ENV['PAYPAL_DEVELOPMENT_CLIENT_SECRET']
                     )
                   end

    @client = PayPal::Client.new(@environment)
  end

  def create_order(amount:, reference_id:, description:, currency: 'USD')
    order_request = OrdersCreateRequest.new
    order_request.prefer('return=representation')
    order_request.request_body = build_order_body(amount, currency, reference_id, description)

    begin
      response = @client.execute(order_request)

      OpenStruct.new(
        id: response.result.id,
        status: response.result.status,
        successful?: response.status_code == 201
      )
    rescue PayPalHttp::HttpError => e
      Rails.logger.error "PayPal order creation failed: #{e.message}"

      OpenStruct.new(
        successful?: false,
        error_message: e.message
      )
    end
  end

  def capture_order(order_id)
    capture_request = OrdersCaptureRequest.new(order_id)
    capture_request.prefer('return=representation')

    begin
      response = @client.execute(capture_request)
      capture = response.result.purchase_units[0].payments.captures[0]

      OpenStruct.new(
        capture_id: capture.id,
        status: capture.status,
        successful?: response.status_code == 201 && capture.status == 'COMPLETED',
        response_data: response.result
      )
    rescue PayPalHttp::HttpError => e
      Rails.logger.error "PayPal capture failed: #{e.message}"

      OpenStruct.new(
        successful?: false,
        error_message: e.message
      )
    end
  end

  def create_payout(recipient_email:, amount:, note:, sender_item_id:, currency: 'USD')
    # PayPal Payouts API implementation
    payout_request = build_payout_request(recipient_email, amount, currency, note, sender_item_id)

    begin
      # This would use PayPal's Payouts API
      # Implementation depends on the specific PayPal SDK
      response = execute_payout(payout_request)

      OpenStruct.new(
        batch_id: response['batch_header']['payout_batch_id'],
        item_id: response['items'][0]['payout_item_id'],
        status: response['batch_header']['batch_status'],
        successful?: response['batch_header']['batch_status'] == 'SUCCESS',
        response_data: response
      )
    rescue StandardError => e
      Rails.logger.error "PayPal payout failed: #{e.message}"

      OpenStruct.new(
        successful?: false,
        error_message: e.message
      )
    end
  end

  def verify_webhook_signature(_payload, headers)
    # PayPal webhook signature verification
    # This would need the actual PayPal webhook verification implementation
    # For now, we'll implement basic verification logic

    webhook_id = Rails.application.credentials.paypal[:webhook_id]
    auth_algo = headers['PAYPAL-AUTH-ALGO']
    transmission_id = headers['PAYPAL-TRANSMISSION-ID']
    cert_id = headers['PAYPAL-CERT-ID']
    transmission_sig = headers['PAYPAL-TRANSMISSION-SIG']
    transmission_time = headers['PAYPAL-TRANSMISSION-TIME']

    # In a real implementation, you would:
    # 1. Get PayPal's public key certificate
    # 2. Verify the signature using the public key
    # 3. Check timestamp to prevent replay attacks

    # For now, we'll just verify that required headers are present
    return false unless auth_algo && transmission_id && cert_id && transmission_sig && transmission_time && webhook_id

    # TODO: Implement actual PayPal webhook signature verification
    # This is a placeholder that should be replaced with real verification
    true
  end

  def cancel_order(order_id)
    # PayPal doesn't have a direct cancel endpoint for orders
    # Orders automatically expire after 3 hours if not captured
    # We'll just log this for now
    Rails.logger.info "PayPal order #{order_id} marked for cancellation (will expire automatically)"

    OpenStruct.new(
      successful?: true,
      message: 'Order marked for cancellation'
    )
  end

  private

  def validate_credentials!
    if Rails.env.production?
      unless Rails.application.credentials.paypal.dig(:client_id) &&
             Rails.application.credentials.paypal.dig(:client_secret)
        raise "PayPal production credentials not configured"
      end
    else
      unless (Rails.application.credentials.paypal.dig(:sandbox_client_id) || ENV['PAYPAL_SANDBOX_CLIENT_ID']) &&
             (Rails.application.credentials.paypal.dig(:sandbox_client_secret) || ENV['PAYPAL_SANDBOX_CLIENT_SECRET'])
        Rails.logger.warn "PayPal sandbox credentials not configured - using environment variables if available"
      end
    end
  end

  def build_order_body(amount, currency, reference_id, description)
    {
      intent: 'CAPTURE',
      purchase_units: [
        {
          reference_id: reference_id,
          description: description,
          amount: {
            currency_code: currency,
            value: format('%.2f', amount)
          }
        }
      ],
      application_context: {
        return_url: "#{Rails.application.config.frontend_url}/payment/success",
        cancel_url: "#{Rails.application.config.frontend_url}/payment/cancel",
        brand_name: 'RavenBoost',
        landing_page: 'BILLING',
        shipping_preference: 'NO_SHIPPING',
        user_action: 'PAY_NOW'
      }
    }
  end

  def build_payout_request(recipient_email, amount, currency, note, sender_item_id)
    {
      sender_batch_header: {
        sender_batch_id: "batch_#{Time.current.to_i}",
        email_subject: 'You have a payout from RavenBoost!',
        email_message: 'You have received a payout for your completed work on RavenBoost.'
      },
      items: [
        {
          recipient_type: 'EMAIL',
          amount: {
            value: format('%.2f', amount),
            currency: currency
          },
          receiver: recipient_email,
          note: note,
          sender_item_id: sender_item_id
        }
      ]
    }
  end

  def execute_payout(payout_request)
    # Implement PayPal Payouts API using REST API
    uri = URI("#{base_url}/v1/payments/payouts")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'
    request['Authorization'] = "Bearer #{get_access_token}"
    request.body = payout_request.to_json

    response = http.request(request)

    if response.code.to_i == 201
      JSON.parse(response.body)
    else
      error_body = JSON.parse(response.body) rescue {}
      raise "PayPal Payout failed: #{error_body['message'] || response.body}"
    end
  end

  def get_access_token
    @access_token ||= fetch_access_token
  end

  def fetch_access_token
    uri = URI("#{base_url}/v1/oauth2/token")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/x-www-form-urlencoded'
    request['Accept'] = 'application/json'

    if Rails.env.production?
      client_id = Rails.application.credentials.paypal.dig(:client_id)
      client_secret = Rails.application.credentials.paypal.dig(:client_secret)
    else
      client_id = Rails.application.credentials.paypal&.dig(:sandbox_client_id) || ENV['PAYPAL_SANDBOX_CLIENT_ID']
      client_secret = Rails.application.credentials.paypal&.dig(:sandbox_client_secret) || ENV['PAYPAL_SANDBOX_CLIENT_SECRET']
    end

    request.basic_auth(client_id, client_secret)
    request.body = 'grant_type=client_credentials'

    response = http.request(request)

    if response.code.to_i == 200
      JSON.parse(response.body)['access_token']
    else
      raise "Failed to get PayPal access token: #{response.body}"
    end
  end

  def base_url
    Rails.env.production? ? 'https://api-m.paypal.com' : 'https://api-m.sandbox.paypal.com'
  end
end
