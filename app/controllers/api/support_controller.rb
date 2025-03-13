module Api
  class SupportController < ApplicationController
    before_action :authenticate_user!
    before_action :ensure_support_staff

    def available_skillmasters
      @skillmasters = User.where(role: 'skillmaster')
                          .where.not(id: Order.in_progress.select(:assigned_skill_master_id))
                          .distinct

      render json: @skillmasters
    end

    def create_urgent_chat
      order = Order.find(params[:order_id])

      chat = Chat.create!(
        chat_type: 'group',
        initiator: current_user,
        status: 'active',
        order: order
      )

      # Add selected skillmasters to chat
      params[:skillmaster_ids].each do |sm_id|
        chat.chat_participants.create!(user_id: sm_id)
      end

      render json: chat, status: :created
    end

    private

    def ensure_support_staff
      return if current_user.role.in?(%w[c_support manager])

      render json: { error: 'Unauthorized' }, status: :forbidden
    end
  end
end
