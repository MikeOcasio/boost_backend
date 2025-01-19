module Users
  class MembersController < ApplicationController
    before_action :authenticate_user!, except: %i[update_password user_exists]
    skip_before_action :authenticate_user!, only: %i[update_password user_exists skillmasters]
    before_action :set_user, only: %i[update destroy add_platform remove_platform lock_user unlock_user]

    # GET /users/member-data/signed_in_user
    def signed_in_user
      user = get_user_from_token
      render json: user.as_json.merge({ sub_platforms: user.sub_platforms_info }), status: :ok
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

    # GET /users/members/user_exists
    def user_exists
      user = User.find_by(email: params[:email])

      if user
        render json: { message: 'User found.', user_id: user.id }, status: :ok
      else
        render json: { error: 'User not found.' }, status: :not_found
      end
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

    def update_password
      # Access the token from params, assuming the request body contains the token
      reset_password_token = params[:reset_password_token]

      # Find the user with the reset password token
      user = User.find_by(reset_password_token: reset_password_token)

      # Use safe navigation to check if the user exists and if the token is still valid
      if user&.reset_password_sent_at && user.reset_password_sent_at > 2.hours.ago
        if user.update(password: params[:password])
          render json: { message: 'Password updated successfully.' }, status: :ok
        else
          render json: { error: 'Failed to update password.', details: user.errors.full_messages }, status: :unprocessable_entity
        end
      else
        render json: { error: 'Invalid or expired token.' }, status: :not_found
      end
    end

    # PATCH/PUT /users/member-data
    def update
      current_user = get_user_from_token # Fetch the current user from the token
      user_to_update = current_user

      # Allow only 'admin' or 'dev' roles to update other users
      if %w[admin dev].include?(current_user.role)
        user_to_update = User.find(params[:id]) # Admins/Devs can update other users
      elsif current_user.id != params[:id].to_i
        # Prevent regular users from updating others
        return render json: { error: 'You are not authorized to update this user' }, status: :forbidden
      end

      # Store the old image URL before the user is updated
      old_image_url = user_to_update.image_url

      if user_to_update.update(user_params)
        # Check if the image_url param is present
        if user_params[:image_url].present?
          # If the new image is a Base64 string, treat it as a new upload regardless of old_image_url
          if user_params[:image_url].start_with?('data:image/')
            # If the old image is an S3 URL, delete it
            delete_image_from_s3(old_image_url) if old_image_url.present? && old_image_url.start_with?('https://')

            # Upload the new Base64 image to S3
            s3_image_url = upload_image_to_s3(user_to_update, user_params[:image_url])
            user_to_update.update(image_url: s3_image_url) # Ensure the correct S3 URL is set

          # Otherwise, it's a direct URL change (assuming S3 URL), so compare and update
          elsif old_image_url != user_params[:image_url]
            # If the old image is an S3 URL, delete it
            delete_image_from_s3(old_image_url) if old_image_url.present? && old_image_url.start_with?('https://')

            # Update the new image URL directly if it's already an S3 URL
            user_to_update.update(image_url: user_params[:image_url])
          end
        end

        render json: user_to_update, status: :ok
      else
        render json: user_to_update.errors, status: :unprocessable_entity
      end
    end

    # DELETE /users/member-data/:id
    def destroy
      current_user = get_user_from_token # Fetch the current user

      if current_user.id == @user.id
        render json: { error: 'You cannot delete yourself.' }, status: :forbidden
      elsif current_user.role == 'customer'
        # Customer can delete their own account (mark as deleted)
        @user.update(deleted_at: Time.current)
        render json: { message: 'Your account has been marked as deleted successfully.' }, status: :ok
      elsif current_user.role == 'admin'
        # Admin can delete any user that is not themselves and not other admins
        if @user.role == 'admin'
          render json: { error: 'You are not authorized to delete this user.' }, status: :forbidden
        else
          @user.update(deleted_at: Time.current)
          render json: { message: 'User account has been marked as deleted successfully.' }, status: :ok
        end
      elsif current_user.role == 'dev'
        # Dev can delete any user except themselves
        @user.update(deleted_at: Time.current)
        render json: { message: 'User account has been marked as deleted successfully.' }, status: :ok
      else
        render json: { error: 'You are not authorized to delete this user.' }, status: :forbidden
      end
    end

    # DELETE /users/members/:id/ban
    def destroy_and_ban
      current_user = get_user_from_token # Fetch the current user

      @user = User.find_by(id: params[:id])
      if @user.nil?
        render json: { error: 'User not found.' }, status: :not_found
        return
      end

      if current_user.role == 'dev'
        if current_user.id == @user.id
          render json: { error: 'You cannot delete yourself.' }, status: :forbidden
        else
          BannedEmail.create!(email: @user.email, user_id: @user.id) # Store user_id
          @user.update(deleted_at: Time.current)
          render json: { message: 'User account has been banned successfully.' }, status: :ok
        end
      elsif current_user.role == 'admin'
        if current_user.id == @user.id
          render json: { error: 'You cannot delete yourself.' }, status: :forbidden
        elsif @user.role == 'admin'
          render json: { error: 'You are not authorized to ban this user.' }, status: :forbidden
        else
          BannedEmail.create!(email: @user.email, user_id: @user.id) # Store user_id
          @user.update(deleted_at: Time.current)
          render json: { message: 'User account has been banned successfully.' }, status: :ok
        end
      else
        render json: { error: 'You are not authorized to ban this user.' }, status: :forbidden
      end
    end

    # POST /users/member-data/:id/platforms
    def add_platform
      current_user = get_user_from_token # Fetch the current user from the token

      if current_user.id == @user.id || current_user.role == 'dev' || current_user.role == 'admin'
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

      if current_user.id == @user.id || current_user.role.in?(%w[dev admin])
        platform = Platform.find(params[:platform_id])
        @user.platforms.delete(platform)
        head :no_content
      else
        render json: { error: 'You are not authorized to remove platforms for this user.' }, status: :forbidden
      end
    end

    # POST /users/members/:id/lock
    def lock_user
      current_user = get_user_from_token

      if current_user.role == 'admin' || current_user.role == 'dev'
        if @user.access_locked?
          render json: { error: 'User account is already locked.' }, status: :unprocessable_entity
        else
          @user.update(locked_by_admin: true)
          @user.lock_access!(send_instructions: false) # Do not send unlock instructions
          render json: { message: 'User account has been locked by admin.' }, status: :ok
        end
      else
        render json: { error: 'You are not authorized to lock this user.' }, status: :forbidden
      end
    end

    # POST /users/members/:id/unlock
    def unlock_user
      current_user = get_user_from_token

      if current_user.role == 'admin' || current_user.role == 'dev'
        if @user.access_locked?
          @user.update(locked_by_admin: false)
          @user.unlock_access!
          render json: { message: 'User account has been unlocked.' }, status: :ok
        else
          render json: { error: 'User account is not locked.' }, status: :unprocessable_entity
        end
      else
        render json: { error: 'You are not authorized to unlock this user.' }, status: :forbidden
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
        :image_url,
        :bio,           # Add bio
        :gamer_tag,     # Add gamer_tag
        achievements: [], # Add achievements array
        gameplay_info: %i[name url] # Add gameplay_info array
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

          return obj.public_url
        end
      else
        raise ArgumentError,
              "Expected an instance of ActionDispatch::Http::UploadedFile or a base64 string, got #{image_param.class.name}"
      end
    end

    def delete_image_from_s3(image_url)
      return unless image_url.present?

      # Extract the S3 object key from the image URL
      object_key = URI(image_url).path[1..] # Remove the leading '/' from the path

      # Find the object in the S3 bucket and delete it
      obj = S3_BUCKET.object(object_key)
      obj.delete if obj.exists?
    end
  end
end
