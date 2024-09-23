# app/controllers/api/platform_credentials_controller.rb
# app/controllers/api/platform_credentials_controller.rb
class Api::PlatformCredentialsController < ApplicationController
  # Ensure the user is authenticated before any action
  before_action :authenticate_user!
  # Set the platform credential instance variable for actions that require it
  before_action :set_platform_credential, only: [:show, :update, :destroy]

  # GET /api/platform_credentials/:id
  # Show a specific platform credential based on the provided ID.
  def show
    # Check if the current user is the owner of the platform credential
    if current_user == @platform_credential.user
      # Render the platform credential in JSON format
      render json: @platform_credential
    else
      # Return an error message and forbidden status if the user is not authorized
      render json: { success: false, message: "Unauthorized access." }, status: :forbidden
    end
  end

  private

  # Set the platform credential instance variable for the actions that require it
  # This method is used before show, update, and destroy actions
  def set_platform_credential
    # Find the platform credential by ID
    @platform_credential = PlatformCredential.find(params[:id])
  end
end

