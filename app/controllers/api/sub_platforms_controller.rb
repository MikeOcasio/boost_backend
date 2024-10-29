class Api::SubPlatformsController < ApplicationController
  # Ensure the user is authenticated before any action
  before_action :authenticate_user!
  before_action :set_platform # Retrieves the platform based on the platform_id parameter
  before_action :validate_platform_supports_sub_platforms, only: [:create]
  before_action :set_sub_platform, only: [:show, :update, :destroy]

  # GET /api/platforms/:platform_id/sub_platforms
  def index
    sub_platforms = @platform.sub_platforms # Scope sub-platforms to the specific platform
    render json: sub_platforms
  end

  # GET /api/platforms/:platform_id/sub_platforms/:id
  def show
    render json: @sub_platform
  end

  # POST /api/platforms/:platform_id/sub_platforms
  def create
    sub_platform = @platform.sub_platforms.new(sub_platform_params)

    if sub_platform.save
      render json: { success: true, message: 'Sub-platform created successfully.', sub_platform: sub_platform },
             status: :created
    else
      render json: { success: false, errors: sub_platform.errors.full_messages },
             status: :unprocessable_entity
    end
  end

  # PATCH/PUT /api/platforms/:platform_id/sub_platforms/:id
  def update
    if @sub_platform.update(sub_platform_params)
      render json: { success: true, message: 'Sub-platform updated successfully.', sub_platform: @sub_platform },
             status: :ok
    else
      render json: { success: false, errors: @sub_platform.errors.full_messages },
             status: :unprocessable_entity
    end
  end

  # DELETE /api/platforms/:platform_id/sub_platforms/:id
  def destroy
    @sub_platform.destroy
    render json: { success: true, message: 'Sub-platform removed successfully.' }, status: :ok
  end

  private

  # Only allow a list of trusted parameters
  def sub_platform_params
    params.require(:sub_platform).permit(:name)
  end

  # Finds the platform based on platform_id parameter and ensures it exists
  def set_platform
    @platform = Platform.find_by(id: params[:platform_id])
    render json: { success: false, message: 'Platform not found' }, status: :not_found unless @platform
  end

  # Checks if the platform supports sub-platforms
  def validate_platform_supports_sub_platforms
    unless @platform.has_sub_platforms
      render json: { success: false, message: 'This platform does not support sub-platforms' },
             status: :unprocessable_entity
    end
  end

  # Finds the specific sub-platform based on id parameter and ensures it belongs to the platform
  def set_sub_platform
    @sub_platform = @platform.sub_platforms.find_by(id: params[:id])
    render json: { success: false, message: 'Sub-platform not found' }, status: :not_found unless @sub_platform
  end
end
