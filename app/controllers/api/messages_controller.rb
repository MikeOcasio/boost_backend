class Api::MessagesController < ApplicationController
  include MessageSerializationConcern

  before_action :authenticate_user!
  before_action :set_chat
  before_action :verify_participant

  def index
    @messages = @chat.messages.includes(:sender).order(created_at: :asc)

    messages_data = @messages.map { |message| serialize_message(message) }

    render json: { messages: messages_data }, status: :ok
  end

  # Optional: Keep this for backwards compatibility or fallback
  # Prefer using WebSocket send_message action in ChatChannel
  def create
    @message = @chat.messages.build(message_params)
    @message.sender = current_user

    if @message.save
      # Message will be broadcast via the after_create_commit callback
      render json: serialize_message(@message), status: :created
    else
      render json: @message.errors, status: :unprocessable_entity
    end
  end

  private

  def set_chat
    @chat = Chat.find(params[:chat_id])
  end

  def verify_participant
    return if @chat.chat_participants.exists?(user_id: current_user.id)

    render json: { error: 'You are not a participant in this chat' }, status: :forbidden
  end

  def message_params
    params.require(:message).permit(:content)
  end
end
