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
