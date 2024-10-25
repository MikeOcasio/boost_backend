# app/controllers/users/sessions_controller.rb
module Users
  class SessionsController < Devise::SessionsController
    respond_to :json

    def create
      user = User.find_by(email: params[:user][:email])

      if BannedEmail.exists?(email: params[:user][:email])
        render json: { error: 'This email is banned and cannot be used to sign in.' }, status: :forbidden
        return
      end

      if user.present? && user.deleted_at.present?
        render json: { error: 'Your account has been deleted. Please re-register.' }, status: :forbidden
        return
      end

      params[:user][:remember_me] = params[:user][:remember_me] if params[:user].key?(:remember_me)

      # Call the original Devise create action
      super
    end

    private

    def respond_with(resource, _opts = {})
      token = request.env['warden-jwt_auth.token']
      qr_code_svg = nil

      # Generate OTP secret and QR code if 2FA isn't set up
      unless resource.otp_required_for_login
        resource.generate_otp_secret_if_missing!
        otp_uri = resource.otp_provisioning_uri(resource.email, issuer: 'RavenBoost')
        qr_code_svg = RQRCode::QRCode.new(otp_uri).as_svg
      end

      render json: {
        message: 'You are logged in.',
        user: resource,
        token: token,
        qr_code: qr_code_svg, # Only includes QR code if 2FA setup is needed
        otp_secret: resource.otp_secret
      }, status: :ok
    end

    def respond_to_on_destroy
      current_user ? log_out_success : log_out_failed
    end

    def log_out_success
      render json: { message: 'You are logged out.' }, status: :ok
    end

    def log_out_failed
      render json: { message: 'Something went wrong.' }, status: :unprocessable_entity
    end
  end
end
