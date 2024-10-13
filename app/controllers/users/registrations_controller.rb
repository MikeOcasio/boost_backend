class Users::RegistrationsController < Devise::RegistrationsController
  respond_to :json

  def create
    # Check if the email is banned
    if BannedEmail.exists?(email: sign_up_params[:email])
      render json: { message: 'This email is banned and cannot be used to register.' }, status: :forbidden
    else
      # Proceed with building the user resource
      build_resource(sign_up_params)

      # Debugging line to check params
      puts "Params: #{params.inspect}"

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
    render json: { message: 'Something went wrong.', errors: resource.errors.full_messages }, status: :unprocessable_entity
  end

  def sign_up_params
    params.require(:user).permit(:email, :password, :password_confirmation, :role, :first_name, :last_name)
  end

end
