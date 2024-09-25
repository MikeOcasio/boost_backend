class ApplicationController < ActionController::Base
  include Devise::Controllers::Helpers

  protect_from_forgery with: :exception, unless: -> { request.format.json? }

  after_action :set_csrf_cookie

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

  private

  def set_csrf_cookie
    cookies['CSRF-TOKEN'] = form_authenticity_token if protect_against_forgery?
  end
end
