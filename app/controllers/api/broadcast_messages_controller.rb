class Api::BroadcastMessagesController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_admin_or_developer

  def create
    ActiveRecord::Base.transaction do
      @chat = Chat.create_broadcast(current_user, broadcast_params[:title])
      @message = @chat.messages.create!(
        content: broadcast_params[:content],
        sender: current_user
      )
    end

    render json: @chat, status: :created
  end

  def index
    @broadcasts = Chat.broadcasts.where(customer_id: current_user.id)
    render json: @broadcasts, include: [:messages]
  end

  private

  def broadcast_params
    params.require(:broadcast).permit(:title, :content)
  end

  def ensure_admin_or_developer
    unless current_user.role.in?(['admin', 'developer'])
      render json: { error: 'Unauthorized' }, status: :unauthorized
    end
  end
end 
