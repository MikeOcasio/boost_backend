module Api
  class ReviewsController < ApplicationController
    # Require authentication for all actions that create or modify reviews
    before_action :authenticate_user!
    # Only allow public access to viewing reviews
    skip_before_action :authenticate_user!, only: %i[index show]
    before_action :set_review, only: %i[show destroy]
    before_action :verify_purchase_eligibility, only: [:create]

    def index
      reviews = case params[:type]
                when 'product'
                  if params[:product_id].present?
                    Product.find(params[:product_id]).reviews
                  else
                    Review.where(reviewable_type: 'Product')
                  end
                when 'skillmaster'
                  if params[:skillmaster_id].present?
                    User.find(params[:skillmaster_id]).reviews.where(review_type: 'user')
                  else
                    Review.where(review_type: 'user')
                  end
                when 'website'
                  Review.where(review_type: 'website')
                when 'order'
                  if params[:order_id].present?
                    Order.find(params[:order_id]).reviews
                  else
                    Review.where(review_type: 'order')
                  end
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
      # Check if user is banned
      if current_user.banned?
        return render json: { error: 'Your account has been banned due to policy violations' }, status: :forbidden
      end

      @review = current_user.reviews.new(review_params)

      # Verify the user can actually review this entity
      unless verify_purchase
        return render json: { error: "You cannot review this #{params[:review][:review_type]}" }, status: :forbidden
      end

      @review.verified_purchase = true

      # Special handling for website reviews
      if params[:review][:review_type] == 'website'
        @review.reviewable_id = 1
        @review.reviewable_type = 'Website'
      end

      if @review.save
        render json: @review, status: :created
      else
        render json: { errors: @review.errors }, status: :unprocessable_entity
      end
    end

    # Add new endpoints

    # GET /api/reviews/reviewable_entities
    # Returns all entities the current user can review
    def reviewable_entities
      completed_orders = current_user.orders.where(state: 'complete').includes(:products)

      render json: {
        orders: completed_orders.map do |order|
          {
            id: order.id,
            internal_id: order.internal_id,
            completed_at: order.updated_at
          }
        end,
        skillmasters: completed_orders.map do |order|
          next if order.assigned_skill_master_id.blank?

          skillmaster = User.find_by(id: order.assigned_skill_master_id)
          next unless skillmaster

          {
            id: skillmaster.id,
            name: "#{skillmaster.first_name} #{skillmaster.last_name}",
            order_id: order.id
          }
        end.compact.uniq { |s| s[:id] },
        products: completed_orders.flat_map do |order|
          order.products.map do |product|
            {
              id: product.id,
              name: product.name,
              order_id: order.id
            }
          end
        end.uniq { |p| p[:id] },
        can_review_website: completed_orders.any?
      }
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
        # Check if user has completed orders with this product
        result = current_user.orders.where(state: 'complete')
                             .joins(:products)
                             .exists?(products: { id: params[:reviewable_id] })
        Rails.logger.info("Product review verification: #{result} for product #{params[:reviewable_id]}")
        result
      when 'user'
        # Check if user has worked with this skillmaster
        result = current_user.orders.where(state: 'complete')
                             .exists?(assigned_skill_master_id: params[:reviewable_id])
        Rails.logger.info("Skillmaster review verification: #{result} for skillmaster #{params[:reviewable_id]}")
        result
      when 'order'
        # Check if user owns this order
        result = current_user.orders.where(state: 'complete')
                             .exists?(id: params[:review][:order_id])
        Rails.logger.info("Order review verification: #{result} for order #{params[:review][:order_id]}")
        result
      when 'website'
        # Allow website review if user has any completed order
        result = current_user.orders.where(state: 'complete').exists?
        Rails.logger.info("Website review verification: #{result}")
        result
      else
        false
      end
    end

    # Modified to accept review_type as a parameter
    def get_reviewable_type(review_type)
      case review_type
      when 'product' then 'Product'
      when 'skillmaster', 'user' then 'User'
      when 'website' then 'Website'
      when 'order' then 'Order'
      end
    end
  end
end
