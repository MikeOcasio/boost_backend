class Api::PlatformCredentialsController < ApplicationController
  # Ensure the user is authenticated before any action
  before_action :authenticate_user!
  # Set the platform credential instance variable for actions that require it
  before_action :set_platform_credential, only: %i[show update destroy]

  # GET /api/platform_credentials/:id
  # Show a specific platform credential based on the provided ID.
  def show
    # Check if the current user is the owner of the platform credential
    if current_user == @platform_credential.user
      # Render the platform credential in JSON format
      render json: @platform_credential
    else
      # Return an error message and forbidden status if the user is not authorized
      render json: { success: false, message: 'Unauthorized access.' }, status: :forbidden
    end
  end

  # POST /api/platform_credentials
  def create
    platform = Platform.find_by(id: params[:platform_id])
    return render json: { success: false, message: 'Platform not found.' }, status: :not_found unless platform

    sub_platform = params[:sub_platform_id].present? ? SubPlatform.find_by(id: params[:sub_platform_id], platform: platform) : nil

    # Enforce that sub-platform credentials can only be created for platforms with `has_sub_platforms: true`
    if sub_platform && !platform.has_sub_platforms
      return render json: { success: false, message: 'Sub-platforms are not allowed for this platform.' }, status: :unprocessable_entity
    end

    unless current_user.platforms.exists?(platform.id)
      current_user.platforms << platform
    end

    # Check for existing credential with the same platform/sub-platform combination
    existing_credential = current_user.platform_credentials.find_by(platform: platform, sub_platform: sub_platform)

    if existing_credential
      if existing_credential.update(username: params[:username], password: params[:password])
        render json: { success: true, message: 'Platform credentials updated successfully.', platform_credential: existing_credential },
               status: :ok
      else
        render json: { success: false, errors: existing_credential.errors.full_messages }, status: :unprocessable_entity
      end
    else
      # Create new platform credential if it doesn't exist
      platform_credential = current_user.platform_credentials.build(
        platform: platform,
        sub_platform: sub_platform,
        username: params[:username],
        password: params[:password]
      )

      if platform_credential.save
        render json: { success: true, message: 'Platform credentials added successfully.', platform_credential: platform_credential },
               status: :created
      else
        render json: { success: false, errors: platform_credential.errors.full_messages }, status: :unprocessable_entity
      end
    end
  end

  # PATCH/PUT /api/platform_credentials/:id
  def update
    if current_user == @platform_credential.user
      platform = @platform_credential.platform
      new_sub_platform = params[:sub_platform_id].present? ? SubPlatform.find_by(id: params[:sub_platform_id], platform: platform) : nil

      # Validate that sub-platform changes align with `has_sub_platforms` restrictions
      if new_sub_platform && !platform.has_sub_platforms
        return render json: { success: false, message: 'Sub-platforms are not allowed for this platform.' }, status: :unprocessable_entity
      end

      if @platform_credential.update(username: params[:username], password: params[:password], sub_platform: new_sub_platform)
        render json: { success: true, message: 'Platform credentials updated successfully.', platform_credential: @platform_credential },
                status: :ok
      else
        render json: { success: false, errors: @platform_credential.errors.full_messages }, status: :unprocessable_entity
      end
    else
      render json: { success: false, message: 'Unauthorized access.' }, status: :forbidden
    end
  end

  # DELETE /api/platform_credentials/:id
  # Destroy a specific platform credential.
  def destroy
    if current_user == @platform_credential.user
      @platform_credential.destroy
      render json: { success: true, message: 'Platform credentials removed successfully.' }, status: :ok
    else
      render json: { success: false, message: 'Unauthorized access.' }, status: :forbidden
    end
  end

  private

  # Set the platform credential instance variable for the actions that require it
  # This method is used before show, update, and destroy actions
  def set_platform_credential
    @platform_credential = PlatformCredential.find_by(id: params[:id])
    render json: { success: false, message: 'Platform credential not found.' }, status: :not_found unless @platform_credential
  end
end
