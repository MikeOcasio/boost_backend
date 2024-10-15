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

  # POST /api/platform_credentials
  # Create a new platform credential for the current user.
  def create
    # Find the platform by id
    platform = Platform.find_by(id: params[:platform_id])

    unless platform
      return render json: { success: false, message: "Platform not found." }, status: :not_found
    end

    # Check if the platform credential already exists for the current user and platform
    existing_credential = current_user.platform_credentials.find_by(platform_id: platform.id)

    if existing_credential
      # If it exists, update it with the new username and password
      existing_credential.update(username: params[:username], password: params[:password])

      if existing_credential.errors.any?
        render json: { success: false, errors: existing_credential.errors.full_messages }, status: :unprocessable_entity
      else
        render json: { success: true, message: "Platform credentials updated successfully.", platform_credential: existing_credential }, status: :ok
      end
    else
      # Build and save a new platform credential if it doesn't exist
      platform_credential = current_user.platform_credentials.build(
        platform: platform,
        username: params[:username],
        password: params[:password]
      )

      # Check if the user has the platform in their platforms
      unless current_user.platforms.exists?(platform.id)
        current_user.platforms << platform  # Add platform to user's platforms
      end

      if platform_credential.save
        render json: { success: true, message: "Platform credentials added successfully.", platform_credential: platform_credential }, status: :created
      else
        render json: { success: false, errors: platform_credential.errors.full_messages }, status: :unprocessable_entity
      end
    end
  end



  # PATCH/PUT /api/platform_credentials/:id
  # Update an existing platform credential.
  def update
    if current_user == @platform_credential.user
      if @platform_credential.update(username: params[:username], password: params[:password])
        render json: { success: true, message: "Platform credentials updated successfully.", platform_credential: @platform_credential }, status: :ok
      else
        render json: { success: false, errors: @platform_credential.errors.full_messages }, status: :unprocessable_entity
      end
    else
      render json: { success: false, message: "Unauthorized access." }, status: :forbidden
    end
  end

  # DELETE /api/platform_credentials/:id
  # Destroy a specific platform credential.
  def destroy
    if current_user == @platform_credential.user
      @platform_credential.destroy
      render json: { success: true, message: "Platform credentials removed successfully." }, status: :ok
    else
      render json: { success: false, message: "Unauthorized access." }, status: :forbidden
    end
  end

  private

  # Set the platform credential instance variable for the actions that require it
  # This method is used before show, update, and destroy actions
  def set_platform_credential
    @platform_credential = PlatformCredential.find(params[:id])
  end
end
