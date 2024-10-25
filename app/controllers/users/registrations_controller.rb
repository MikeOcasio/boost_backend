class Users::RegistrationsController < Devise::RegistrationsController
  respond_to :json

  def create
    if BannedEmail.exists?(email: sign_up_params[:email])
      render json: { message: 'This email is banned and cannot be used to register.' }, status: :forbidden
      return
    end

    existing_user = User.find_by(email: sign_up_params[:email])

    if existing_user
      if existing_user.deleted_at.present?
        existing_user.update(deleted_at: nil, password: sign_up_params[:password], password_confirmation: sign_up_params[:password_confirmation])
        render json: { message: 'Your account has been restored successfully.', user: existing_user }, status: :ok
      else
        render json: { message: 'Email has already been taken.' }, status: :unprocessable_entity
      end
    else
      build_resource(sign_up_params)

      # Generate OTP secret and QR code after user creation
      if resource.save
        resource.generate_otp_secret_if_missing! # Generate OTP secret
        otp_uri = resource.otp_provisioning_uri(resource.email, issuer: 'RavenBoost') # Generate OTP URI
        qr_code_svg = RQRCode::QRCode.new(otp_uri).as_svg # Generate QR code SVG

        yield resource if block_given?
        register_success(qr_code_svg) # Pass QR code SVG to success response
      else
        register_failed
      end
    end
  end

  private

  def register_success(qr_code_svg)
    render json: {
      message: 'Signed up successfully.',
      user: resource,
      qr_code: qr_code_svg,
      otp_secret: resource.otp_secret # Send the OTP secret (optional)
    }, status: :ok
  end

  def register_failed
    render json: { message: 'Something went wrong.', errors: resource.errors.full_messages }, status: :unprocessable_entity
  end

  def sign_up_params
    params.require(:user).permit(:email, :password, :password_confirmation, :role, :first_name, :last_name)
  end
end

