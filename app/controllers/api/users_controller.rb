require 'jwt'

class Api::UsersController < ApplicationController
  include ActionController::HttpAuthentication::Token::ControllerMethods

  # Skip CSRF token verification for API requests
  skip_before_action :verify_authenticity_token

  # Set the user for actions that need it (show, update, destroy)
  before_action :set_user, only: [:show, :update, :destroy]

  # POST /api/users/login
  # Log in a user and generate a JWT token
  def login
    @user = User.find_by(email: params[:email])

    if @user&.valid_password?(params[:password])
      # Sign in the user (Devise method)
      sign_in @user

      # Define payload for JWT
      payload = { user_id: @user.id }
      secret = Rails.application.credentials[:devise_jwt_secret_key]
      algorithm = 'HS256'

      # Manually encode the JWT token
      token = JWT.encode payload, secret, algorithm

      puts "Encoded Token: #{token}"

      # Return the token in the response
      render json: { token: token }
    else
      # If authentication fails, return an error
      render json: { error: 'Invalid email or password' }, status: :unauthorized
    end
  end

  # GET /api/users/current
  # Retrieve the current logged-in user based on JWT token
  def current_user
    authenticate_with_http_token do |token, _options|
      puts "Authorization Header: #{request.headers['Authorization']}"
      puts "Token: #{token}"
      secret = Rails.application.credentials[:devise_jwt_secret_key]
      algorithm = 'HS256'

      # Manually decode the JWT token
      begin
        decoded_token = JWT.decode token, secret, true, { algorithm: algorithm }
        puts "Decoded Token: #{decoded_token}"
        User.find(decoded_token[0]['user_id'])
      rescue JWT::DecodeError => e
        puts "JWT Decode Error: #{e.message}"
        nil
      end
    end
  end

  # GET /api/users
  # Return a list of all users
  def index
    @users = User.all
    render json: @users
  end

  # GET /api/users/:id
  # Return details of a specific user
  def show
    render json: @user
  end

  # POST /api/users
  # Create a new user
  def create
    @user = User.new(user_params)

    # Handle image upload if provided
    if params[:image].present?
      upload_image_to_s3(@user, params[:image])
    end

    if @user.save
      # Return the created user in JSON format with a created status
      render json: @user, status: :created
    else
      # Return validation errors if save fails
      render json: @user.errors, status: :unprocessable_entity
    end
  end


    # PATCH/PUT /api/users/:id
    # Update details of a specific user
  def update
    if @user.update(user_params)
      # Handle image upload if provided
      if params[:image].present?
        upload_image_to_s3(@user, params[:image])
      end
      render json: @user, status: :ok
    else
      # Return validation errors if update fails
      render json: @user.errors, status: :unprocessable_entity
    end
  end

  # DELETE /api/users/:id
  # Delete a specific user
  def destroy
    @user.destroy
    # Return no content status to indicate successful deletion
    head :no_content
  end

  # GET /api/users/skillmasters
  # Retrieve a list of users with the 'skillmaster' role
  def skillmasters
    @users = User.where(role: 'skillmaster')
    render json: @users
  end

  # POST /api/users/:id/enable_two_factor
  # Enable two-factor authentication for a user
  def enable_two_factor
    @user.otp_required_for_login = true
    @user.otp_secret = User.generate_otp_secret
    @user.save!

    # Send OTP secret to the user's email
    UserMailer.otp(@user, @user.otp_secret).deliver_now
    render json: { message: 'OTP has been sent to your email.' }
  end

  # POST /api/users/:id/disable_two_factor
  # Disable two-factor authentication for a user
  def disable_two_factor
    @user.otp_required_for_login = false
    @user.otp_secret = nil
    @user.save!
    head :no_content
  end

  # POST /api/users/:id/verify_two_factor
  # Verify a two-factor authentication code
  def verify_two_factor
    if @user.validate_and_consume_otp!(params[:otp_attempt])
      render json: { success: true }
    else
      render json: { success: false }, status: :unauthorized
    end
  end

  # POST /api/users/:id/generate_backup_codes
  # Generate backup codes for two-factor authentication
  def generate_backup_codes
    @user.generate_otp_backup_codes!
    @user.save!
    # Return the backup codes to the user
    render json: { backup_codes: @user.otp_backup_codes }
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
