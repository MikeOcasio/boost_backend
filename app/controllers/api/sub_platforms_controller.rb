class Api::SubPlatformsController < ApplicationController
  # Ensure the user is authenticated before any action
  before_action :authenticate_user!

  # GET /api/platforms/:platform_id/sub_platforms
  def index
    sub_platforms = SubPlatform.all
    render json: sub_platforms
  end

  # GET /api/platforms/:platform_id/sub_platforms/:id
  def show
    render json: @sub_platform
  end

  # POST /api/platforms/:platform_id/sub_platforms
  def create
    sub_platform = SubPlatform.new(sub_platform_params) # Use the retrieved platform

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
    params.require(:sub_platform).permit(:name, :platform_id)
  end
end
