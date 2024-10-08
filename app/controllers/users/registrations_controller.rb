class Users::RegistrationsController < Devise::RegistrationsController
  respond_to :json

  def create
    build_resource(sign_up_params)

    # Debugging line to inspect parameters
    puts "Params: #{params.inspect}"

    # Check if an image is present and upload it to S3
    upload_image_to_s3(resource, params[:image]) if params[:image].present?

    resource.save
    yield resource if block_given?

    if resource.persisted?
      register_success
    else
      register_failed
    end
  end

  private

  def register_success
    render json: { message: 'Signed up successfully.', user: resource }, status: :ok
  end

  def register_failed
    render json: { message: 'Something went wrong.', errors: resource.errors.full_messages }, status: :unprocessable_entity
  end

  def sign_up_params
    params.require(:user).permit(
      :email,
      :password,
      :password_confirmation,
      :role,
      :first_name,
      :last_name,
      :image
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
