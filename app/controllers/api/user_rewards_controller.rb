module Api
  class UserRewardsController < ApplicationController
    before_action :authenticate_user!
    before_action :set_reward, only: [:claim]

    def index
      render json: {
        completion: {
          total_points: current_user.completion_points,
          available_points: current_user.available_completion_points,
          next_threshold: current_user.next_completion_reward,
          rewards: UserReward::COMPLETION_THRESHOLDS
        },
        referral: {
          total_points: current_user.referral_points,
          available_points: current_user.available_referral_points,
          next_threshold: current_user.next_referral_reward,
          rewards: UserReward::REFERRAL_THRESHOLDS,
          referral_link: current_user.referral_link
        },
        earned_rewards: current_user.user_rewards
      }
    end

    def claim
      reward = current_user.user_rewards.find(params[:id])

      ActiveRecord::Base.transaction do
        if current_user.deduct_points(reward.points, reward.reward_type)
          reward.update!(status: 'claimed', claimed_at: Time.current)
          render json: reward
        else
          render json: { error: 'Insufficient points' }, status: :unprocessable_entity
        end
      end
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'Reward not found' }, status: :not_found
    end

    def award_completion_points
      order = Order.find(params[:order_id])

      if order.complete? && order.user == current_user
        points_to_award = calculate_completion_points(order)

        ActiveRecord::Base.transaction do
          current_user.increment!(:total_completion_points, points_to_award)
          current_user.increment!(:available_completion_points, points_to_award)

          render json: {
            message: "Awarded #{points_to_award} completion points",
            total_points: current_user.total_completion_points,
            available_points: current_user.available_completion_points
          }
        end
      else
        render json: { error: 'Invalid order' }, status: :unprocessable_entity
      end
    end

    def award_referral_points
      order = Order.find(params[:order_id])
      referrer = User.find(params[:referrer_id])

      if order.complete? && order.total >= 10.00
        points_to_award = 10 # Standard referral points

        ActiveRecord::Base.transaction do
          referrer.increment!(:total_referral_points, points_to_award)
          referrer.increment!(:available_referral_points, points_to_award)

          render json: {
            message: "Awarded #{points_to_award} referral points",
            total_points: referrer.total_referral_points,
            available_points: referrer.available_referral_points
          }
        end
      else
        render json: { error: 'Invalid order for referral' }, status: :unprocessable_entity
      end
    end

    private

    def set_reward
      @reward = current_user.user_rewards.find(params[:id])
    end

    def calculate_completion_points(order)
      case order.total
      when 0..9.99
        1  # 1 point for orders under $10
      when 10..49.99
        5  # 5 points for orders $10-$49.99
      when 50..99.99
        10 # 10 points for orders $50-$99.99
      when 100..199.99
        15 # 15 points for orders $100-$199.99
      else
        # For orders $200+, give 20 points plus 1 point per additional $10
        20 + ((order.total - 200) / 10).floor
      end
    end
  end
end
