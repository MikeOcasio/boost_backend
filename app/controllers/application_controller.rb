class ApplicationController < ActionController::Base
  include Devise::Controllers::Helpers

  def health_check
    render plain: "OK", status: :ok
  end

  def csrf_token
    token = form_authenticity_token
    Rails.logger.debug("CSRF Token: #{token}")
    render json: { csrf_token: token }, status: :ok
  end

end
