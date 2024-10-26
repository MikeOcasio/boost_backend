class Api::SubPlatformsController < ApplicationController
  # Only allow admin users to create, update, and delete sub-platforms
  before_action :authenticate_user!
  before_action :set_sub_platform, only: %i[show create update destroy]

  # GET /api/sub_platforms
  # Retrieve a list of all sub-platforms
  def index
    sub_platforms = SubPlatform.all
    render json: sub_platforms
  end

  # GET /api/sub_platforms/:id
  # Retrieve a specific sub-platform by ID
  def show
    render json: @sub_platform
  end

  # POST /api/sub_platforms
  # Create a new sub-platform
  def create
    sub_platform = SubPlatform.new(sub_platform_params)

    if sub_platform.save
      render json: { success: true, message: 'Sub-platform created successfully.', sub_platform: sub_platform },
             status: :created
    else
      render json: { success: false, errors: sub_platform.errors.full_messages },
             status: :unprocessable_entity
    end
  end

  # PATCH/PUT /api/sub_platforms/:id
  # Update an existing sub-platform
  def update
    if @sub_platform.update(sub_platform_params)
      render json: { success: true, message: 'Sub-platform updated successfully.', sub_platform: @sub_platform },
             status: :ok
    else
      render json: { success: false, errors: @sub_platform.errors.full_messages },
             status: :unprocessable_entity
    end
  end

  # DELETE /api/sub_platforms/:id
  # Destroy a specific sub-platform
  def destroy
    @sub_platform.destroy
    render json: { success: true, message: 'Sub-platform removed successfully.' }, status: :ok
  end

  private

  # Set the sub-platform instance variable
  def set_sub_platform
    @sub_platform = SubPlatform.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { success: false, message: 'Sub-platform not found.' }, status: :not_found
  end

  # Only allow a list of trusted parameters through
  def sub_platform_params
    params.require(:sub_platform).permit(:name, :platform_id)
  end

  # Authorize admin users
  def authorize_admin!
    render json: { success: false, message: 'Unauthorized access.' }, status: :forbidden unless current_user.admin?
  end
end
