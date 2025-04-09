module Api
  module Staff
    class ReviewModerationsController < ApplicationController
      before_action :authenticate_user!
      before_action :authorize_staff!
      before_action :set_review, only: [:create]

      def create
        @moderation = ReviewModeration.new(moderation_params)
        @moderation.moderator = current_user
        @moderation.user = @review.user
        @moderation.review = @review

        ActiveRecord::Base.transaction do
          if @moderation.save
            # Update the review to mark as moderated
            @review.update!(
              moderated_at: Time.current,
              moderated_by: current_user,
              moderation_reason: @moderation.reason
            )

            render json: {
              message: 'Review moderated successfully',
              strikes: @review.user.strikes,
              banned: @review.user.banned?
            }, status: :created
          else
            render json: { errors: @moderation.errors.full_messages }, status: :unprocessable_entity
          end
        end
      end

      private

      def authorize_staff!
        unless current_user.admin? || current_user.dev? ||
               current_user.c_support? || current_user.manager?
          render json: { error: 'Unauthorized' }, status: :forbidden
        end
      end

      def set_review
        @review = Review.find(params[:review_id])
      end

      def moderation_params
        params.require(:moderation).permit(:reason, :strike_applied)
      end
    end
  end
end
