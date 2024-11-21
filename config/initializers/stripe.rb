# config/initializers/stripe.rb
require 'stripe'
Stripe.api_key = Rails.application.credentials.stripe[:secret_key]
# Stripe.api_key = 'sk_test_51Q9rdFKtclhwv0vlAZIfMiBATbFSnHTOOGN7qemvPUeFyn6lKAEFyuiSnotPId8EIF9o0bICY5JrVY39gTK4qvAt00ksBff9a6'
