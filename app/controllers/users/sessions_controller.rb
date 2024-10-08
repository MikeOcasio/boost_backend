# app/controllers/users/sessions_controller.rb
module Users
  class SessionsController < Devise::SessionsController
    respond_to :json

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
