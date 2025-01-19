class Users::TwoFactorAuthenticationController < ApplicationController
  before_action :authenticate_user!

  def show
    # Generate OTP and QR code only if setup is incomplete
    if current_user.otp_setup_complete
      render json: { message: '2FA is already set up' }, status: :ok
    else
      current_user.generate_otp_secret_if_missing!

      otp_uri = current_user.otp_provisioning_uri(current_user.email, issuer: 'RavenBoost')
      qr_code_svg = RQRCode::QRCode.new(otp_uri).as_svg

      render json: {
        qr_code: qr_code_svg,
        otp_secret: current_user.otp_secret
      }, status: :ok
    end
  end

  def verify
    if current_user.validate_and_consume_otp!(params[:otp_attempt])
      # Mark the setup as complete only after a successful OTP verification
      current_user.update(otp_required_for_login: true, otp_setup_complete: true)
      render json: { message: 'OTP verified and 2FA enabled' }, status: :ok
    else
      render json: { error: 'Invalid OTP' }, status: :unprocessable_entity
    end
  end

  def update_method
    if %w[app email].include?(params[:method])
      current_user.update(two_factor_method: params[:method])
      render json: { message: '2FA method updated successfully' }, status: :ok
    else
      render json: { error: 'Invalid 2FA method' }, status: :unprocessable_entity
    end
  end
end
