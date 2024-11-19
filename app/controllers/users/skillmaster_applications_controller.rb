class Users::SkillmasterApplicationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_application, only: %i[show update]
  before_action :ensure_customer_role, only: [:create]
  before_action :check_application_editability, only: [:update]

  # GET /users/skillmaster_applications/:id
  def show
    if authorized_to_view?(@application)
      render json: @application
    else
      render json: { error: 'Unauthorized access' }, status: :unauthorized
    end
  end

  # GET /users/skillmaster_applications
  def index
    if current_user.role == 'admin' || current_user.role == 'dev'
      @applications = SkillmasterApplication.all
    else
      @applications = SkillmasterApplication.where(user_id: current_user.id)
    end

    render json: @applications
  end

  # POST /users/skillmaster_applications
  def create
    if SkillmasterApplication.exists?(user_id: current_user.id)
      return render json: { error: 'You can only have one active application at a time' }, status: :unprocessable_entity
    end

    if current_user.role == 'skillmaster' || recently_denied?
      return render json: { error: 'You cannot apply at this time' }, status: :forbidden
    end

    @application = SkillmasterApplication.new(application_params.merge(user_id: current_user.id))
    handle_image_uploads if params[:images]
    @application.status = 'submitted'

    if @application.save
      render json: @application, status: :created
    else
      render json: @application.errors, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /users/skillmaster_applications/:id
  def update
    if @application.update(application_params)
      render json: @application
    else
      render json: @application.errors, status: :unprocessable_entity
    end
  end

  private

  def set_application
    @application = SkillmasterApplication.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Application not found' }, status: :not_found
  end

  def ensure_customer_role
    render json: { error: 'Only customers can create applications' }, status: :forbidden unless current_user.role == 'customer'
  end

  def check_application_editability
    if @application.reviewer_id.present? && !current_user.role == 'admin' && !current_user.role == 'dev'
      render json: { error: 'You cannot update this application after it is under review' }, status: :forbidden
    end
  end

  def authorized_to_view?(application)
    current_user.role == 'admin' || current_user.role == 'dev' || application.user_id == current_user.id
  end

  def recently_denied?
    # Find the last denied SkillmasterApplication where the current_user's id is present
    last_denied = SkillmasterApplication.where(user_id: current_user.id, status: 'denied').order(:reviewed_at).last

    # Check if there's a denied application and if the reviewed_at date is within the last 30 days
    last_denied.present? && last_denied.reviewed_at > 30.days.ago
  end

  def handle_image_uploads
    uploaded_images = Array(params[:images]).map { |file| upload_to_s3(file) }
    @application.images = uploaded_images
  end

  def application_params
    params.require(:skillmaster_application).permit(:gamer_tag, :reasons, :reviewer_id, category_ids: [], platform_ids: [], images: [], channels: [])
  end

  def upload_to_s3(file)
    if file.is_a?(ActionDispatch::Http::UploadedFile)
      obj = S3_BUCKET.object("skillmaster_applications/#{file.original_filename}")
      obj.upload_file(file.tempfile, content_type: file.content_type)
      obj.public_url
    elsif file.is_a?(String) && file.start_with?('data:image/')
      base64_data = file.split(',')[1]
      decoded_data = Base64.decode64(base64_data)

      filename = "skillmaster_applications/#{SecureRandom.uuid}.jpeg"

      Tempfile.create(['skillmaster_image', '.jpeg']) do |temp_file|
        temp_file.binmode
        temp_file.write(decoded_data)
        temp_file.rewind

        obj = S3_BUCKET.object(filename)
        obj.upload_file(temp_file, content_type: 'image/jpeg')

        return obj.public_url
      end
    else
      raise ArgumentError, 'Invalid file format'
    end
  end
end
