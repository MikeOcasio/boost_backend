module Api
  module Staff
    class UserProfilesController < ApplicationController
      before_action :authenticate_user!
      before_action :ensure_staff
      before_action :ensure_active_chat_with_user

      def show
        render json: {
          profile: user_profile,
          chats: user_chats,
          rewards: user_rewards,
          wallet: user_wallet,
          referrals: user_referrals
        }
      end

      private

      def target_user
        @target_user ||= User.find(params[:id])
      end

      def ensure_staff
        return if current_user.role.in?(%w[admin dev c_support manager skillmaster])

        render json: { error: 'Unauthorized' }, status: :forbidden
      end

      def ensure_active_chat_with_user
        has_active_chat = Chat.active
                              .joins(:chat_participants)
                              .where(chat_participants: { user_id: [current_user.id, target_user.id] })
                              .group(:id)
                              .having('COUNT(DISTINCT chat_participants.user_id) = 2')
                              .exists?

        return if has_active_chat

        render json: { error: 'No active chat with this user' }, status: :forbidden
      end

      def user_profile
        {
          id: target_user.id,
          email: target_user.email,
          first_name: target_user.first_name,
          last_name: target_user.last_name,
          role: target_user.role,
          gamer_tag: target_user.gamer_tag,
          bio: target_user.bio
        }
      end

      def user_chats
        target_user.chats.includes(:participants).map do |chat|
          {
            id: chat.id,
            type: chat.chat_type,
            status: chat.status,
            created_at: chat.created_at
          }
        end
      end

      def user_rewards
        target_user.user_rewards.map do |reward|
          {
            id: reward.id,
            points: reward.points,
            reward_type: reward.reward_type,
            status: reward.status,
            amount: reward.amount
          }
        end
      end

      def user_wallet
        # Implement wallet info based on your wallet model
        {
          balance: target_user.wallet&.balance || 0,
          pending_balance: target_user.wallet&.pending_balance || 0
        }
      end

      def user_referrals
        target_user.referrals.map do |referral|
          {
            id: referral.id,
            status: referral.state,
            created_at: referral.created_at
          }
        end
      end
    end
  end
end
