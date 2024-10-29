class PromotionsController < ApplicationController
  before_action :set_promotion, only: [:show, :update, :destroy, :apply_to_order]

  # GET /promotions
  def index
    @promotions = Promotion.all
    render json: @promotions
  end

  # GET /promotions/:id
  def show
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
    @promotion.destroy
    head :no_content
  end

  # POST /promotions/:id/apply_to_order
  def apply_to_order
    order = Order.find(params[:order_id])

    if @promotion.active? && order.apply_promotion(@promotion)
      render json: { message: "Promotion applied successfully!" }, status: :ok
    else
      render json: { error: "Unable to apply promotion. It may be inactive or already applied to this order." }, status: :unprocessable_entity
    end
  end

  private

  # Set promotion for actions that require it
  def set_promotion
    @promotion = Promotion.find(params[:id])
  end

  # Strong parameters for creating and updating promotions
  def promotion_params
    params.require(:promotion).permit(:code, :discount_percentage, :start_date, :end_date)
  end
end
