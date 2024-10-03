class Api::SessionsController < ApplicationController

  respond_to :json

  def create
    @user = User.find_by(email: params[:email])

    if @user&.valid_password?(params[:password])
      sign_in @user
      token = @user.generate_jwt  # Ensure this method exists to generate a JWT
      render json: { message: 'Logged in successfully', token: token }, status: :ok
    else
      render json: { error: 'Invalid email or password' }, status: :unauthorized
    end
  end

  def destroy
    current_user&.jwt_denylist.create! # Add to denylist
    render json: { message: 'Logged out successfully' }, status: :ok
  end

  def show
    user = current_user
    if user
      render json: user, status: :ok
    else
      render json: { error: 'Unauthorized access' }, status: :unauthorized
    end
  end
end
