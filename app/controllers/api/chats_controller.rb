class Api::ChatsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_chat, only: %i[show update archive]

  def index
    @chats = Chat.includes(:messages, :participants, :initiator, :recipient)
                 .where(id: accessible_chat_ids)
                 .order(created_at: :desc)

    chat_data = @chats.map do |chat|
      # Get the last message with sender information
      last_message = chat.messages.includes(:sender).order(created_at: :desc).first

      {
        id: chat.id,
        chat_type: chat.chat_type,
        title: chat.title,
        status: chat.status,
        ticket_number: chat.ticket_number,
        created_at: chat.created_at,
        updated_at: chat.updated_at,
        initiator: {
          id: chat.initiator.id,
          first_name: chat.initiator.first_name,
          last_name: chat.initiator.last_name,
          email: chat.initiator.email,
          role: chat.initiator.role,
          image_url: chat.initiator.image_url
        },
        recipient: if chat.recipient
                     {
                       id: chat.recipient.id,
                       first_name: chat.recipient.first_name,
                       last_name: chat.recipient.last_name,
                       email: chat.recipient.email,
                       role: chat.recipient.role,
                       image_url: chat.recipient.image_url
                     }
                   else
                     nil
                   end,
        participants: chat.participants.map do |participant|
          {
            id: participant.id,
            first_name: participant.first_name,
            last_name: participant.last_name,
            email: participant.email,
            role: participant.role,
            image_url: participant.image_url
          }
        end,
        last_message: if last_message
                        {
                          id: last_message.id,
                          content: last_message.content,
                          created_at: last_message.created_at,
                          read: last_message.read,
                          sender: {
                            id: last_message.sender.id,
                            first_name: last_message.sender.first_name,
                            last_name: last_message.sender.last_name,
                            role: last_message.sender.role,
                            image_url: last_message.sender.image_url
                          }
                        }
                      else
                        nil
                      end
      }
    end

    render json: chat_data, status: :ok
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
