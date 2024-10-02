class ApplicationController < ActionController::Base
  include Devise::Controllers::Helpers

  protect_from_forgery with: :exception, unless: -> { request.format.json? }

  after_action :set_csrf_cookie

  # Health check endpoint
  def health_check
    render plain: "OK", status: :ok
  end
end
