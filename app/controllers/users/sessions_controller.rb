# app/controllers/users/sessions_controller.rb
class Users::SessionsController < Devise::SessionsController
  respond_to :json

  def create
    user = User.find_by(email: params[:user][:email])

    if user.nil?
      render json: { error: 'User not found. Please register.' }, status: :not_found
      return
    end

    if BannedEmail.exists?(email: params[:user][:email])
      render json: { error: 'This email is banned and cannot be used to sign in.' }, status: :forbidden
      return
    end

    if user.deleted_at.present?
      render json: { error: 'Your account has been deleted. Please re-register.' }, status: :forbidden
      return
    end

    # Remember me functionality if passed
    params[:user][:remember_me] = params[:user][:remember_me] if params[:user].key?(:remember_me)

    # Check if OTP setup is incomplete
    if user.otp_secret.blank? || !user.otp_setup_complete
      # User does not have OTP fully set up; generate the OTP secret and QR code
      user.generate_otp_secret_if_missing!
      otp_uri = user.otp_provisioning_uri(user.email, issuer: 'RavenBoost')
      qr_code_svg = RQRCode::QRCode.new(otp_uri).as_svg

      # Set otp_required_for_login to false until setup is complete
      user.update!(otp_required_for_login: false)

      render json: {
        message: '2FA is not fully set up. Please scan the QR code to set it up.',
        qr_code: qr_code_svg
      }, status: :ok
      return
    end

    # Require OTP if setup is complete
    otp_attempt = params[:user][:otp_attempt]

    if user.otp_required_for_login && otp_attempt.blank?
      render json: { error: 'OTP required' }, status: :unauthorized
      return
    elsif user.otp_required_for_login && !user.validate_and_consume_otp!(otp_attempt)
      render json: { error: 'Invalid OTP code' }, status: :unauthorized
      return
    end

    # If OTP is validated, mark setup as complete
    user.update!(otp_setup_complete: true, otp_required_for_login: true) if user.otp_secret.present?

    # Continue with the login
    super
  end

  private

  def respond_with(resource, _opts = {})
    token = request.env['warden-jwt_auth.token']
    render json: {
      message: 'You are logged in.',
      user: resource,
      token: token
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
