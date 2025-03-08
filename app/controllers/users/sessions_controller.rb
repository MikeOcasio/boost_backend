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

    # Check maintenance access before proceeding with authentication
    app_status = AppStatus.current
    if (app_status.maintenance? || params[:under_construction]) && !%w[admin dev].include?(user.role)
      render json: { error: 'Only admins and devs can log in during maintenance.' }, status: :forbidden
      return
    end

    # Remember me functionality if passed
    params[:user][:remember_me] = params[:user][:remember_me] if params[:user].key?(:remember_me)

    # Continue with the login
    super
  end

  private

  def respond_with(resource, _opts = {})
    session_token = request.env['warden-jwt_auth.token']

    # Generate maintenance token only if site is in maintenance and user is admin/dev
    maintenance_token = if AppStatus.current.maintenance? && %w[admin dev].include?(resource.role)
                          payload = JWT.decode(session_token, Rails.application.credentials.devise_jwt_secret_key, true).first
                          payload['type'] = 'maintenance' # Add type claim to distinguish token
                          JWT.encode(payload, Rails.application.credentials.devise_jwt_secret_key)
                        end

    render json: {
      message: resource.role.in?(%w[admin dev]) ? 'You are logged in.' : 'Only admins and devs can log in during maintenance.',
      user: resource,
      token: session_token,
      maintenance_token: maintenance_token
    }, status: maintenance_token.nil? && AppStatus.current.maintenance? ? :forbidden : :ok
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
