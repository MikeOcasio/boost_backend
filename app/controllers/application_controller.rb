# app/controllers/application_controller.rb
class ApplicationController < ActionController::API
  include Devise::Controllers::Helpers

  # Health check endpoint
  def health_check
    render plain: 'OK', status: :ok
  end
end
