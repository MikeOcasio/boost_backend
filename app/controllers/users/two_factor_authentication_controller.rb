class Users::TwoFactorAuthenticationController < ApplicationController
  before_action :authenticate_user!

  # Generates OTP secret and QR code
  def show
    # Generate OTP secret if missing and save it
    current_user.generate_otp_secret_if_missing!

    # Ensure the OTP secret is saved to the database
    current_user.save if current_user.changed?

    # Generate a provisioning URI to use with Google Authenticator or any TOTP app
    otp_uri = current_user.otp_provisioning_uri(current_user.email, issuer: 'RavenBoost')

    # Generate a QR code based on the OTP URI
    qr_code_svg = RQRCode::QRCode.new(otp_uri).as_svg

    render json: { qr_code: qr_code_svg, otp_secret: current_user.otp_secret }, status: :ok
  end


  # Verifies the OTP
  def verify
    if current_user.validate_and_consume_otp!(params[:otp_attempt])
      current_user.update(otp_required_for_login: true)
      render json: { message: 'OTP verified and 2FA enabled' }, status: :ok
    else
      render json: { error: 'Invalid OTP' }, status: :unprocessable_entity
    end
  end
end
