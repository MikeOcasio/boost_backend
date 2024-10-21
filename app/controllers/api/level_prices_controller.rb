module Api
  class LevelPricesController < ApplicationController
    before_action :authenticate_user!
    before_action :set_level_price, only: [:show, :update, :destroy]
    before_action :authorize_admin_or_dev, only: [:create, :update, :destroy]

    # GET /level_prices
    def index
      @level_prices = LevelPrice.all
      render json: @level_prices
    end

    # GET /level_prices/:id
    def show
      render json: @level_price
    end

    # POST /level_prices
    def create
      @level_price = LevelPrice.new(level_price_params)

      if @level_price.save
        render json: @level_price, status: :created
      else
        render json: @level_price.errors, status: :unprocessable_entity
      end
    end

    # PUT /level_prices/:id
    def update
      if @level_price.update(level_price_params)
        render json: @level_price
      else
        render json: @level_price.errors, status: :unprocessable_entity
      end
    end

    # DELETE /level_prices/:id
    def destroy
      @level_price.destroy
      head :no_content
    end

    private

    # Find LevelPrice by ID
    def set_level_price
      @level_price = LevelPrice.find(params[:id])
    end

    # Strong parameters
    def level_price_params
      params.require(:level_price).permit(:category_id, :min_level, :max_level, :price_per_level)
    end

    # Authorize only admins or devs for create, update, destroy actions
    def authorize_admin_or_dev
      current_user = get_user_from_token
      unless current_user.role == 'admin' || current_user.role == 'dev'
        render json: { error: 'Unauthorized access' }, status: :forbidden
      end
    end

    # Method to get the current user from JWT token
    def get_user_from_token
      token = request.headers['Authorization'].split(' ')[1]
      jwt_payload = JWT.decode(
        token,
        Rails.application.credentials.devise_jwt_secret_key,
        true, # Verify the signature
        { algorithm: 'HS256' }
      )

      user_id = jwt_payload[0]['sub']
      User.find(user_id.to_s)
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'User not found' }, status: :not_found
    rescue JWT::DecodeError
      render json: { error: 'Invalid token' }, status: :unauthorized
    end
  end
end
