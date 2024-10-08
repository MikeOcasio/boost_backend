require_relative 'boot'

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module OperationBoost
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.0

    # config/application.rb

    # config.action_controller.default_protect_from_forgery = true
    # config.action_controller.allow_forgery_protection = true

    config.session_store :cookie_store, key: '_operation_boost_session', domain: :allow

    config.middleware.use ActionDispatch::Cookies

    config.middleware.use config.session_store, config.session_options

    # Ensure SameSite attribute is set correctly
    # config.action_dispatch.cookies_same_site_protection = :none

    # Ensure secure attribute is set correctly
    # config.session_store :cookie_store, key: '_operation_boost_session', secure: Rails.env.production?

    # Ensure domain attribute is set correctly
    # config.session_store :cookie_store, key: '_operation_boost_session', domain: :all

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration can go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded after loading
    # the framework and any gems in your application.
  end
end
