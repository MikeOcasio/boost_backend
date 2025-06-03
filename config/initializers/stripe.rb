# config/initializers/stripe.rb
require 'stripe'
Stripe.api_key = Rails.application.credentials.stripe[:test_secret]

# Add these configuration options for Connect
Stripe.max_network_retries = 2
Stripe.open_timeout = 30
Stripe.read_timeout = 80
