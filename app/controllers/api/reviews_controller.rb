module Api
  class ReviewsController < ApplicationController
    before_action :authenticate_user!, except: %i[index show]
    before_action :set_review, only: %i[show destroy]
    before_action :verify_purchase_eligibility, only: [:create]

    def index
      reviews = case params[:type]
                when 'product'
                  Product.find(params[:product_id]).reviews
                when 'skillmaster'
                  User.find(params[:skillmaster_id]).reviews.where(review_type: 'skillmaster')
                when 'website'
                  Review.where(review_type: 'website')
                when 'order'
                  Order.find(params[:order_id]).reviews
                when 'customer'
                  # Get reviews about this customer (as a skillmaster)
                  User.find(params[:customer_id]).received_reviews
                else
                  # Allow filtering by user who wrote the review
                  params[:user_id] ? Review.where(user_id: params[:user_id]) : Review.all
                end

      render json: reviews.includes(:user).as_json(include: {
                                                     user: { only: %i[id first_name last_name avatar_url] }
                                                   })
    end

    def create
      @review = current_user.reviews.new(review_params)
      @review.verified_purchase = verify_purchase

      if @review.save
        render json: @review, status: :created
      else
        render json: { errors: @review.errors }, status: :unprocessable_entity
      end
    end

    private

    def review_params
      params.require(:review).permit(:rating, :content, :review_type, :order_id)
            .merge(reviewable_type: get_reviewable_type, reviewable_id: params[:reviewable_id])
    end

    def verify_purchase_eligibility
      return if params[:review_type] == 'website'

      return if current_user.orders.completed.exists?

      render json: { error: 'Must have completed orders to review' }, status: :forbidden
    end

    def verify_purchase
      case review_params[:review_type]
      when 'product'
        current_user.orders.completed.joins(:products)
                    .exists?(products: { id: params[:reviewable_id] })
      when 'skillmaster'
        current_user.orders.completed
                    .exists?(assigned_skill_master_id: params[:reviewable_id])
      when 'order'
        current_user.orders.completed
                    .exists?(id: review_params[:order_id])
      else
        false
      end
    end

    def get_reviewable_type
      case review_params[:review_type]
      when 'product' then 'Product'
      when 'skillmaster' then 'User'
      when 'website' then 'Website'
      when 'order' then 'Order'
      end
    end
  end
end
