class Api::UsersController < ApplicationController
  include ActionController::HttpAuthentication::Token::ControllerMethods

  #! Remove this line once login is implemented
  skip_before_action :verify_authenticity_token

  before_action :set_user, only: [:show, :update, :destroy, :add_platform, :remove_platform, :enable_two_factor, :disable_two_factor, :verify_two_factor, :generate_backup_codes]

  # POST /api/users/login
  def login
    @user = User.find_by(email: params[:email])

    if @user&.valid_password?(params[:password])
      sign_in @user
      payload = { user_id: @user.id }
      secret = Rails.application.credentials[:devise_jwt_secret_key]
      algorithm = 'HS256'
      token = JWT.encode payload, secret, algorithm
      puts "Encoded Token: #{token}"
      render json: { token: token }
    else
      render json: { error: 'Invalid email or password' }, status: :unauthorized
    end
  end

  # GET /api/users/current
  def current_user
    authenticate_with_http_token do |token, _options|
      secret = Rails.application.credentials[:devise_jwt_secret_key]
      algorithm = 'HS256'

      begin
        decoded_token = JWT.decode token, secret, true, { algorithm: algorithm }
        User.find(decoded_token[0]['user_id'])
      rescue JWT::DecodeError => e
        nil
      end
    end
  end

  # GET /api/users
  def index
    @users = User.all
    render json: @users
  end

  # GET /api/users/:id
  def show
    render json: @user
  end

  # POST /api/users
  def create
    @user = User.new(user_params)
    upload_image_to_s3(@user, params[:image]) if params[:image].present?

    if @user.save
      render json: @user, status: :created
    else
      render json: @user.errors, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /api/users/:id
  def update
    if @user.update(user_params)
      upload_image_to_s3(@user, params[:image]) if params[:image].present?
      render json: @user, status: :ok
    else
      render json: @user.errors, status: :unprocessable_entity
    end
  end

  # DELETE /api/users/:id
  def destroy
    @user.destroy
    head :no_content
  end

  # GET /api/users/skillmasters
  def skillmasters
    @users = User.where(role: 'skillmaster')
    render json: @users
  end

  # POST /api/users/:id/enable_two_factor
  def enable_two_factor
    @user.otp_required_for_login = true
    @user.otp_secret = User.generate_otp_secret
    @user.save!
    UserMailer.otp(@user, @user.otp_secret).deliver_now
    render json: { message: 'OTP has been sent to your email.' }
  end

  # POST /api/users/:id/disable_two_factor
  def disable_two_factor
    @user.otp_required_for_login = false
    @user.otp_secret = nil
    @user.save!
    head :no_content
  end

  # POST /api/users/:id/verify_two_factor
  def verify_two_factor
    if @user.validate_and_consume_otp!(params[:otp_attempt])
      render json: { success: true }
    else
      render json: { success: false }, status: :unauthorized
    end
  end

  # POST /api/users/:id/generate_backup_codes
  def generate_backup_codes
    @user.generate_otp_backup_codes!
    @user.save!
    render json: { backup_codes: @user.otp_backup_codes }
  end

  # GET /api/users/:id/platforms
  # Retrieve all platforms associated with a specific user
  def platforms
    render json: @user.platforms
  end

  # POST /api/users/:id/platforms
  # Associate a platform with a user
  def add_platform
    platform = Platform.find(params[:platform_id])
    @user.platforms << platform unless @user.platforms.include?(platform)

    render json: @user, status: :created
  end

  # DELETE /api/users/:id/platforms/:platform_id
  # Disassociate a platform from a user
  def remove_platform
    platform = Platform.find(params[:platform_id])
    @user.platforms.delete(platform)

    head :no_content
  end

  private

  # Set the user instance variable based on the provided ID
  def set_user
    @user = User.find(params[:id])
  end

  # Permit only the trusted parameters for creating or updating a user
  def user_params
    params.require(:user).permit(:email, :password, :first_name, :last_name, :role, :image_url)
  end

  # Upload the image to S3 and update the user's image_url
  def upload_image_to_s3(user, image)
    s3_object = S3_BUCKET.object("user_images/#{user.id}/#{image.original_filename}")
    s3_object.upload_file(image.tempfile)
    user.update(image_url: s3_object.public_url)
  end
end
