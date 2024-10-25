class Users::TwoFactorAuthenticationController < ApplicationController
  before_action :authenticate_user!

  def show
    current_user.generate_otp_secret_if_missing!
    otp_uri = current_user.otp_provisioning_uri(current_user.email, issuer: 'RavenBoost')
    qr_code_svg = RQRCode::QRCode.new(otp_uri).as_svg

    render json: { qr_code: qr_code_svg, otp_secret: current_user.otp_secret }, status: :ok
  end

  def verify
    if current_user.validate_and_consume_otp!(params[:otp_attempt])
      current_user.update(otp_required_for_login: true)
      render json: { message: 'OTP verified and 2FA enabled' }, status: :ok
    else
      render json: { error: 'Invalid OTP' }, status: :unprocessable_entity
    end
  end
end
