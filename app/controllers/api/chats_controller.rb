class Api::ChatsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_chat, only: %i[show update archive]

  def index
    @chats = Chat.includes(:messages, :participants)
                 .where(id: accessible_chat_ids)
                 .order(created_at: :desc)

    render json: @chats, include: %i[messages participants]
  end

  def show
    render json: @chat, include: [:messages]
  end

  def create
    @chat = Chat.new(chat_params)
    @chat.initiator = current_user

    # For group chats, set the first non-initiator participant as recipient
    if @chat.chat_type == 'group' && params[:chat][:participant_ids].present?
      other_participants = params[:chat][:participant_ids].map(&:to_i) - [current_user.id]
      @chat.recipient_id = other_participants.first if other_participants.any?
    end

    if @chat.save
      create_initial_participants
      render json: @chat, status: :created
    else
      render json: @chat.errors, status: :unprocessable_entity
    end
  end

  def update
    if @chat.update(chat_params)
      render json: @chat
    else
      render json: @chat.errors, status: :unprocessable_entity
    end
  end

  def archive
    if @chat.archive!
      render json: @chat
    else
      render json: @chat.errors, status: :unprocessable_entity
    end
  end

  private

  def set_chat
    @chat = Chat.find(params[:id])
  end

  def chat_params
    params.require(:chat).permit(
      :chat_type,
      :title,
      :recipient_id,
      :order_id,
      participant_ids: []
    )
  end

  def create_initial_participants
    case @chat.chat_type
    when 'group'
      # Add all specified participants
      (params[:chat][:participant_ids] || []).each do |user_id|
        @chat.chat_participants.create(user_id: user_id)
      end
      # Add initiator if not already included
      @chat.chat_participants.create(user_id: current_user.id) unless @chat.participant_ids.include?(current_user.id)
    when 'direct', 'support'
      @chat.chat_participants.create(user_id: @chat.initiator_id)
      @chat.chat_participants.create(user_id: @chat.recipient_id)
    end
  end

  def accessible_chat_ids
    ChatParticipant.where(user_id: current_user.id).pluck(:chat_id)
  end
end
