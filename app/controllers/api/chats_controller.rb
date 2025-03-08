class Api::ChatsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_chat, only: %i[show update]

  def index
    @chats = if current_user.role == 'customer'
               Chat.where(customer_id: current_user.id)
             else
               Chat.where(booster_id: current_user.id)
             end

    render json: @chats, include: [:messages]
  end

  def show
    render json: @chat, include: [:messages]
  end

  def update
    if @chat.update(chat_params)
      render json: @chat
    else
      render json: @chat.errors, status: :unprocessable_entity
    end
  end

  def create
    @chat = Chat.new(chat_params)
    @chat.customer_id = current_user.id if current_user.role == 'customer'

    if @chat.save
      render json: @chat, status: :created
    else
      render json: @chat.errors, status: :unprocessable_entity
    end
  end

  private

  def set_chat
    @chat = Chat.find(params[:id])
  end

  def chat_params
    params.require(:chat).permit(:booster_id)
  end
end
