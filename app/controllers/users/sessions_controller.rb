# app/controllers/users/sessions_controller.rb
module Users
  class SessionsController < Devise::SessionsController
    respond_to :json

    def create
      # Check if the email is banned
      if BannedEmail.exists?(email: params[:user][:email])
        render json: { error: 'This email is banned and cannot be used to sign in.' }, status: :forbidden
        return
      end

      super # Call the original Devise create action
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
