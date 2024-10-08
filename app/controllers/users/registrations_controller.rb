class Users::RegistrationsController < Devise::RegistrationsController
  respond_to :json

  def create
    build_resource(sign_up_params)

    puts "Params: #{params.inspect}"  # Debugging line

    resource.save
    yield resource if block_given?

    if resource.persisted?
      register_success
    else
      register_failed
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
