# app/controllers/application_controller.rb
class ApplicationController < ActionController::API
  include Devise::Controllers::Helpers

  # Health check endpoint
  def health_check
    render plain: "OK", status: :ok
  end

  private

  # Ensure the user is authenticated for protected actions
  def authenticate_user!
    unless user_signed_in?
      render json: { error: 'Unauthorized access' }, status: :unauthorized
    end
  end

  # Provide access to the current user
  def current_user
    decoded = decoded_token
    Rails.logger.debug("Current User Decoded JWT: #{decoded}")  # Log the decoded token

    @current_user ||= User.find_by(id: decoded) if decoded.present?
  end


  # Optional: Customize error handling for Devise
  def respond_with(resource, options = {})
    super(resource, options) do |format|
      format.json { render json: resource }
    end
  end

  # Method to decode JWT token (if you're using JWT)
  def decoded_token
    if request.headers['Authorization'].present?
      Rails.logger.debug("Authorization header: #{request.headers['Authorization']}")  # Log the Authorization header
      token = request.headers['Authorization'].split(' ').last
      Rails.logger.debug("JWT token: #{token}")  # Log the JWT token
      begin
        decoded = JWT.decode(token, Rails.application.credentials.devise_jwt_secret_key, true, { algorithm: 'HS256' })
        Rails.logger.debug("Decoded JWT: #{decoded.inspect}")  # Log the decoded JWT

        # Extract the user ID from the first element of the decoded array
        user_id = decoded[0]['user_id']  # Change this to 'user_id' to match your token payload
        Rails.logger.debug("Extracted User ID: #{user_id}")  # Log the extracted User ID
        user_id  # Return user ID directly
      rescue JWT::DecodeError
        Rails.logger.error("JWT Decode Error: #{$!}")
        nil
      end
    end
  end
end
