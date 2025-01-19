class Users::RegistrationsController < Devise::RegistrationsController
  respond_to :json

  def create
    # Check if the email is banned
    if BannedEmail.exists?(email: sign_up_params[:email])
      render json: { message: 'This email is banned and cannot be used to register.' }, status: :forbidden
      return
    end

    # Attempt to find an existing user
    existing_user = User.find_by(email: sign_up_params[:email])

    if existing_user
      if existing_user.deleted_at.present?
        # Restore the user account if it's marked as deleted
        existing_user.update(deleted_at: nil, password: sign_up_params[:password],
                             password_confirmation: sign_up_params[:password_confirmation])
        render json: { message: 'Your account has been restored successfully.', user: existing_user }, status: :ok
      else
        # If the user is active, return an error
        render json: { message: 'Email has already been taken.' }, status: :unprocessable_entity
      end
    else
      # Proceed with building the user resource
      build_resource(sign_up_params)

      resource.two_factor_method = params[:user][:two_factor_method] # Capture the user's choice

      # Save the resource
      if resource.save
        yield resource if block_given?
        register_success
      else
        register_failed
      end
    end
  end

  private

  def register_success
    render json: { message: 'Signed up successfully.', user: resource }, status: :ok
  end

  def register_failed
    render json: { message: 'Something went wrong.', errors: resource.errors.full_messages },
           status: :unprocessable_entity
  end

  def sign_up_params
    params.require(:user).permit(:email, :password, :password_confirmation, :role, :first_name, :last_name, :two_factor_method)
  end
end
