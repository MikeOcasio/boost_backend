class Api::UsersController < ApplicationController
  include ActionController::HttpAuthentication::Token::ControllerMethods

  #! Remove this line once login is implemented
  skip_before_action :verify_authenticity_token

  before_action :set_user, only: [:show, :update, :destroy, :add_platform, :remove_platform, :enable_two_factor, :disable_two_factor, :verify_two_factor, :generate_backup_codes]
  before_action :set_default_format

  # POST /api/users/login
  def login
    @user = User.find_by(email: params[:email])

    if @user&.valid_password?(params[:password])
      sign_in @user
      payload = { user_id: @user.id }
      secret = Rails.application.credentials.devise_jwt_secret_key
      algorithm = 'HS256'
      token = JWT.encode payload, secret, algorithm
      puts "Encoded Token: #{token}"
      render json: { token: token }
    else
      render json: { error: 'Invalid email or password' }, status: :unauthorized
    end
  end

  # GET /api/users/:id
  def show
    if @user
      render json: @user, status: :ok
    else
      render json: { error: 'User not found' }, status: :not_found
    end
  end

  # GET /api/current_user
  def show_current_user
    user = current_user
    if user
      render json: user, status: :ok
    else
      render json: { error: 'Unauthorized access' }, status: :unauthorized
    end
  end

  # GET /api/users
  def index
    @users = User.all
    render json: @users
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

  def set_default_format
    request.format = :json
  end

  # Set the user instance variable based on the provided ID
  def set_user
    @user = User.find(params[:id])
  end

  def current_user
    authenticate_with_http_token do |token, _options|
      secret = Rails.application.credentials.devise_jwt_secret_key
      algorithm = 'HS256'

      Rails.logger.debug "Starting current_user method"

      begin
        Rails.logger.debug "Received token: #{token}"

        # Decode the JWT token
        decoded_token = JWT.decode(token, secret, true, { algorithm: algorithm })
        Rails.logger.debug "Decoded token: #{decoded_token}"

        # Extract user ID from decoded token
        user_id = decoded_token[0]['user_id']
        Rails.logger.debug "Extracted user_id: #{user_id}"

        # Find the user by user_id
        @user = User.find(user_id)
        Rails.logger.debug "User found: #{@user.inspect}"

        @user # Return the user object without rendering anything here
      rescue JWT::DecodeError => e
        Rails.logger.error "JWT Decode Error: #{e.message}"
        nil # Return nil to indicate failure
      rescue ActiveRecord::RecordNotFound => e
        Rails.logger.error "Record Not Found: #{e.message}"
        nil # Return nil to indicate failure
      rescue StandardError => e
        Rails.logger.error "Unexpected Error: #{e.message}"
        nil # Return nil to indicate failure
      ensure
        Rails.logger.debug "Ending current_user method"
      end
    end
  end

  # Permit only the trusted parameters for creating or updating a user
  def user_params
    params.require(:user).permit(
      :email,
      :password,
      :first_name,
      :last_name,
      :role,
      :image_url
    )
  end

  def upload_image_to_s3(user, image_param)
    if image_param.is_a?(ActionDispatch::Http::UploadedFile)
      # Handle file upload
      obj = S3_BUCKET.object("users/#{image_param.original_filename}")
      obj.upload_file(image_param.tempfile)
      user.image_url = obj.public_url  # Assuming `image_url` is an attribute of User model
    elsif image_param.is_a?(String) && image_param.start_with?('data:image/')
      # Handle base64 image upload
      base64_data = image_param.split(',')[1]
      decoded_data = Base64.decode64(base64_data)

      # Generate a unique filename for the image
      filename = "users/#{SecureRandom.uuid}.webp" # Change the extension as necessary

      Tempfile.create(['user_image', '.webp']) do |temp_file|
        temp_file.binmode
        temp_file.write(decoded_data)
        temp_file.rewind

        # Upload to S3
        obj = S3_BUCKET.object(filename)
        obj.upload_file(temp_file)
        user.image_url = obj.public_url  # Assuming `image_url` is an attribute of User model
      end
    else
      raise ArgumentError, "Expected an instance of ActionDispatch::Http::UploadedFile or a base64 string, got #{image_param.class.name}"
    end
  end
end
