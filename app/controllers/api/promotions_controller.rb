module Api
  class PromotionsController < ApplicationController
    before_action :set_promotion, only: %i[show update destroy]
    before_action :authenticate_user!
    before_action :authorize_admin!, only: %i[show create update destroy index]

    # GET /promotions
    def index
      @promotions = Promotion.all
      render json: @promotions
    end

    # GET /promotions/:id
    def show
      render json: @promotion
    end

    # GET /promotions/by_code
    def show_by_code
      @promotion = Promotion.find_by(code: params[:code])
      return render json: { error: 'Promotion not found' }, status: :not_found if @promotion.nil?

      render json: @promotion
    end

    # POST /promotions
    def create
      @promotion = Promotion.new(promotion_params)

      if @promotion.save
        render json: @promotion, status: :created
      else
        render json: @promotion.errors, status: :unprocessable_entity
      end
    end

    # PATCH/PUT /promotions/:id
    def update
      if @promotion.update(promotion_params)
        render json: @promotion
      else
        render json: @promotion.errors, status: :unprocessable_entity
      end
    end

    # DELETE /promotions/:id
    def destroy
      if @promotion.nil?
        return render json: { error: 'Promotion not found or already deleted.' }, status: :not_found
      end

      @promotion.destroy
      head :no_content
    end

    private

    # Ensure the user is an admin or dev
    def authorize_admin!
      return render json: { error: 'Access denied' }, status: :forbidden unless admin?
    end

    def set_promotion
      @promotion = Promotion.find_by(id: params[:id])
      render json: { error: 'Promotion not found' }, status: :not_found if @promotion.nil?
    end

    def promotion_params
      params.require(:promotion).permit(:code, :discount_percentage, :start_date, :end_date)
    end

    def admin?
      current_user.role == 'admin' || current_user.role == 'dev'
    end
  end
end
