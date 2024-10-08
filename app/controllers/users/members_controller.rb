module Users
  class MembersController < ApplicationController
    before_action :authenticate_user!
    before_action :set_user, only: [:show, :update, :destroy, :add_platform, :remove_platform]

    # GET /users/member-data/signed_in_user
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

    # GET /users/members/skillmasters
    def skillmasters
      @users = User.where(role: 'skillmaster')
      render json: @users
    end

    # GET /users/members/skillmasters/:id
    def show_skillmaster
      # Find the skillmaster by the provided ID
      @skillmaster = User.find_by(id: params[:id], role: 'skillmaster')

      if @skillmaster
        render json: @skillmaster, status: :ok
      else
        render json: { error: 'Skillmaster not found.' }, status: :not_found
      end
    end


    # PATCH/PUT /users/member-data
    def update
      current_user = get_user_from_token # Fetch the current user from the token

      if current_user.update(user_params)
        upload_image_to_s3(current_user, params[:image]) if params[:image].present?
        render json: current_user, status: :ok
      else
        render json: current_user.errors, status: :unprocessable_entity
      end
    end

    # DELETE /users/member-data
    def destroy
      user_to_destroy = get_user_from_token # Fetch the user from the token
      current_user = @user # Assuming @user is set in the before_action

      if current_user.id == user_to_destroy.id || current_user.role.in?(["dev", "admin"])
        user_to_destroy.destroy # Destroy the user
        head :no_content # Return a success response
      else
        render json: { error: 'You are not authorized to delete this user.' }, status: :forbidden
      end
    end

    # GET /users/member-data/platforms
    def platforms
      current_user = get_user_from_token # Fetch the current user from the token
      render json: current_user.platforms, status: :ok
    end


    # POST /users/member-data/:id/platforms
    def add_platform
      current_user = get_user_from_token # Fetch the current user from the token

      if current_user.id == @user.id || current_user.role.in?(["dev", "admin"])
        platform = Platform.find(params[:platform_id])
        @user.platforms << platform unless @user.platforms.include?(platform)
        render json: @user, status: :created
      else
        render json: { error: 'You are not authorized to add platforms for this user.' }, status: :forbidden
      end
    end

    # DELETE /users/member-data/:id/platforms/:platform_id
    def remove_platform
      current_user = get_user_from_token # Fetch the current user from the token

      if current_user.id == @user.id || current_user.role.in?(["dev", "admin"])
        platform = Platform.find(params[:platform_id])
        @user.platforms.delete(platform)
        head :no_content
      else
        render json: { error: 'You are not authorized to remove platforms for this user.' }, status: :forbidden
      end
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
