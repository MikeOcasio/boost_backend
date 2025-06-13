# PayPal and Trolley Configuration
#
# This initializer sets up configuration for PayPal and Trolley services
# Make sure to add the required credentials to your Rails credentials file

Rails.application.configure do
  # PayPal Configuration
  config.paypal = begin
    config_for(:paypal)
  rescue StandardError
    {}
  end

  # Trolley Configuration
  config.trolley = begin
    config_for(:trolley)
  rescue StandardError
    {}
  end

  # Validate required credentials in production
  if Rails.env.production?
    required_paypal_keys = %i[client_id client_secret webhook_id]
    required_trolley_keys = %i[api_key api_secret]

    missing_paypal = required_paypal_keys.reject { |key| Rails.application.credentials.paypal&.key?(key) }
    missing_trolley = required_trolley_keys.reject { |key| Rails.application.credentials.trolley&.key?(key) }

    Rails.logger.warn "Missing PayPal credentials: #{missing_paypal.join(', ')}" if missing_paypal.any?

    Rails.logger.warn "Missing Trolley credentials: #{missing_trolley.join(', ')}" if missing_trolley.any?
  end
end
