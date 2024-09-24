class ApplicationController < ActionController::Base
  include Devise::Controllers::Helpers

  def health_check
    render plain: "OK", status: :ok
  end

  def csrf_token
    render json: { csrf_token: form_authenticity_token }
  end

end
