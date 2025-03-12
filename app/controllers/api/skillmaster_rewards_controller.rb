module Api
  class SkillmasterRewardsController < ApplicationController
    before_action :authenticate_user!
    before_action :ensure_skillmaster

    def index
      render json: {
        completion: {
          points: current_user.completion_points,
          next_threshold: current_user.next_completion_reward,
          rewards: SkillmasterReward::COMPLETION_THRESHOLDS
        },
        referral: {
          points: current_user.referral_points,
          next_threshold: current_user.next_referral_reward,
          rewards: SkillmasterReward::REFERRAL_THRESHOLDS,
          referral_link: current_user.referral_link
        },
        earned_rewards: current_user.skillmaster_rewards
      }
    end

    def claim
      reward = current_user.skillmaster_rewards.find(params[:id])
      if reward.update(status: 'claimed', claimed_at: Time.current)
        render json: reward
      else
        render json: { errors: reward.errors }, status: :unprocessable_entity
      end
    end

    private

    def ensure_skillmaster
      return if current_user.role == 'skillmaster'

      render json: { error: 'Access denied' }, status: :forbidden
    end
  end
end
