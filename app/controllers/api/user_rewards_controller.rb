module Api
  class UserRewardsController < ApplicationController
    before_action :authenticate_user!
    before_action :set_reward, only: [:claim]

    def index
      render json: {
        completion: {
          points: current_user.completion_points,
          next_threshold: current_user.next_completion_reward,
          rewards: UserReward::COMPLETION_THRESHOLDS
        },
        referral: {
          points: current_user.referral_points,
          next_threshold: current_user.next_referral_reward,
          rewards: UserReward::REFERRAL_THRESHOLDS,
          referral_link: current_user.referral_link
        },
        earned_rewards: current_user.user_rewards
      }
    end

    def claim
      reward = current_user.user_rewards.find(params[:id])
      if reward.update(status: 'claimed', claimed_at: Time.current)
        render json: reward
      else
        render json: { errors: reward.errors }, status: :unprocessable_entity
      end
    end

    private

    def set_reward
      @reward = current_user.user_rewards.find(params[:id])
    end
  end
end
