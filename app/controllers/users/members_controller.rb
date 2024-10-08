module Users
  class MembersController < ApplicationController
    before_action :authenticate_user!
    before_action :set_user, only: [:show, :update, :destroy, :add_platform, :remove_platform]

    # GET /member-data/:id
    def show
      user = get_user_from_token
      render json: user, status: :ok
    end

    # GET GET /users/member-data/signed_in_user
    def signed_in_user
      user = get_user_from_token
      render json: user, status: :ok
    end

    # GET /users/members
    # New action to get all users
    def index
      @users = User.all
      render json: @users, status: :ok
    end

    # GET users/members/skillmasters
    def skillmasters
      @users = User.where(role: 'skillmaster')
      render json: @users
    end


    # POST /member-data
    def create
      @user = User.new(user_params)
      upload_image_to_s3(@user, params[:image]) if params[:image].present?

      if @user.save
        render json: @user, status: :created
      else
        render json: @user.errors, status: :unprocessable_entity
      end
    end

    # PATCH/PUT users/member-data/:id
    def update
      if @user.update(user_params)
        upload_image_to_s3(@user, params[:image]) if params[:image].present?
        render json: @user, status: :ok
      else
        render json: @user.errors, status: :unprocessable_entity
      end
    end

    # DELETE /member-data/:id
    def destroy
      @user.destroy
      head :no_content
    end

    # GET /member-data/:id/platforms
    def platforms
      render json: @user.platforms, status: :ok
    end

    # POST /member-data/:id/platforms
    def add_platform
      platform = Platform.find(params[:platform_id])
      @user.platforms << platform unless @user.platforms.include?(platform)
      render json: @user, status: :created
    end

    # DELETE /member-data/:id/platforms/:platform_id
    def remove_platform
      platform = Platform.find(params[:platform_id])
      @user.platforms.delete(platform)
      head :no_content
    end

    private

    def get_user_from_token
      token = request.headers['Authorization'].split(' ')[1]
      jwt_payload = JWT.decode(
        token,
        Rails.application.credentials.devise_jwt_secret_key,
        true, # Verify the signature
        { algorithm: 'HS256' }
      )

      user_id = jwt_payload[0]['sub']
      User.find(user_id.to_s)
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'User not found' }, status: :not_found
    rescue JWT::DecodeError
      render json: { error: 'Invalid token' }, status: :unauthorized
    end

    def set_user
      @user = User.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'User not found' }, status: :not_found
    end

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
        user.image_url = obj.public_url
      elsif image_param.is_a?(String) && image_param.start_with?('data:image/')
        # Handle base64 image upload
        base64_data = image_param.split(',')[1]
        decoded_data = Base64.decode64(base64_data)

        # Generate a unique filename for the image
        filename = "users/#{SecureRandom.uuid}.webp"

        Tempfile.create(['user_image', '.webp']) do |temp_file|
          temp_file.binmode
          temp_file.write(decoded_data)
          temp_file.rewind

          # Upload to S3
          obj = S3_BUCKET.object(filename)
          obj.upload_file(temp_file)
          user.image_url = obj.public_url
        end
      else
        raise ArgumentError, "Expected an instance of ActionDispatch::Http::UploadedFile or a base64 string, got #{image_param.class.name}"
      end
    end
  end
end
