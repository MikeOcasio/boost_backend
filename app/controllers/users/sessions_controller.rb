# app/controllers/users/sessions_controller.rb
module Users
  class SessionsController < Devise::SessionsController
    respond_to :json

    def create
      # First, fetch the user based on the email provided
      user = User.find_by(email: params[:user][:email])

      # Check if the email is banned
      if BannedEmail.exists?(email: params[:user][:email])
        render json: { error: 'This email is banned and cannot be used to sign in.' }, status: :forbidden
        return
      end

      # If user is found, check if the account has been deleted
      if user.present? && user.deleted_at.present?
        render json: { error: 'Your account has been deleted. Please re-register.' }, status: :forbidden
        return
      end

      # Call the original Devise create action
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
      if current_user
        log_out_success
      else
        log_out_failed
      end
    end

    def log_out_success
      render json: {
        message: 'You are logged out.',
      }, status: :ok
    end

    def log_out_failed
      render json: {
        message: 'Something went wrong.',
      }, status: :unprocessable_entity
    end

  end
end
