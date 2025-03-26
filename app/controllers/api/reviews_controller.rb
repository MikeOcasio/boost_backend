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

      # Special handling for website reviews
      if params[:review][:review_type] == 'website'
        @review.reviewable_id = Website.instance.id
        @review.reviewable_type = 'Website'
      end

      if @review.save
        render json: @review, status: :created
      else
        render json: { errors: @review.errors }, status: :unprocessable_entity
      end
    end

    private

    def review_params
      # Store review_type in a local variable to avoid recursion
      review_type = params[:review][:review_type]

      params.require(:review)
            .permit(:rating, :content, :review_type, :order_id)
            .merge(reviewable_type: get_reviewable_type(review_type),
                   reviewable_id: params[:reviewable_id])
    end

    def verify_purchase_eligibility
      return if params[:review][:review_type] == 'website'

      # Change from .completed to .where(state: 'complete')
      return if current_user.orders.where(state: 'complete').exists?

      render json: { error: 'Must have completed orders to review' }, status: :forbidden
    end

    # Also update verify_purchase to avoid the same issue
    def verify_purchase
      review_type = params[:review][:review_type]

      case review_type
      when 'product'
        current_user.orders.where(state: 'complete').joins(:products)
                    .exists?(products: { id: params[:reviewable_id] })
      when 'skillmaster'
        current_user.orders.where(state: 'complete')
                    .exists?(assigned_skill_master_id: params[:reviewable_id])
      when 'order'
        current_user.orders.where(state: 'complete')
                    .exists?(id: params[:review][:order_id])
      else
        false
      end
    end

    # Modified to accept review_type as a parameter
    def get_reviewable_type(review_type)
      case review_type
      when 'product' then 'Product'
      when 'skillmaster' then 'User'
      when 'website' then 'Website'
      when 'order' then 'Order'
      end
    end
  end
end
