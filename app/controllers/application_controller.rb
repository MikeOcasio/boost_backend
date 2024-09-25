class ApplicationController < ActionController::Base
  include Devise::Controllers::Helpers

  protect_from_forgery with: :exception, unless: -> { request.format.json? }

  # Health check endpoint
  def health_check
    render plain: "OK", status: :ok
  end

  # CSRF token endpoint
  def csrf_token
    token = form_authenticity_token
    Rails.logger.debug("CSRF Token: #{token}")  # Log the token
    render json: { csrf_token: token }, status: :ok
  end
end

