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
    Rails.logger.info "Chat creation params: #{params.inspect}"

    @chat = Chat.new(chat_params)
    @chat.initiator = current_user

    Rails.logger.info "Chat after chat_params: initiator_id=#{@chat.initiator_id}, recipient_id=#{@chat.recipient_id}, chat_type=#{@chat.chat_type}"

    # Set recipient based on chat type
    case @chat.chat_type
    when 'direct', 'support'
      # For direct and support chats, recipient should be explicitly provided
      # Check both nested and top-level params for recipient_id
      recipient_id = params[:chat][:recipient_id] || params[:recipient_id]
      @chat.recipient_id = recipient_id

      Rails.logger.info "Setting recipient_id to: #{recipient_id} for #{@chat.chat_type} chat"

      # Ensure we don't create a chat where user talks to themselves
      if @chat.recipient_id == current_user.id
        Rails.logger.warn "Attempted to create self-chat: initiator=#{current_user.id}, recipient=#{@chat.recipient_id}"
        render json: { error: 'Cannot create a chat with yourself' }, status: :unprocessable_entity
        return
      end

      # Check if a chat already exists between these users (in either direction)
      existing_chat = Chat.where(
        '(initiator_id = ? AND recipient_id = ?) OR (initiator_id = ? AND recipient_id = ?)',
        current_user.id, @chat.recipient_id, @chat.recipient_id, current_user.id
      ).where(chat_type: @chat.chat_type).first

      if existing_chat
        Rails.logger.info "Found existing chat: #{existing_chat.id}"
        render json: existing_chat, status: :ok
        return
      end

    when 'group'
      # For group chats, set the first non-initiator participant as recipient
      if params[:chat][:participant_ids].present?
        other_participants = params[:chat][:participant_ids].map(&:to_i) - [current_user.id]
        @chat.recipient_id = other_participants.first if other_participants.any?
        Rails.logger.info "Setting group chat recipient_id to: #{@chat.recipient_id}"
      end
    end

    Rails.logger.info "Final chat before save: initiator_id=#{@chat.initiator_id}, recipient_id=#{@chat.recipient_id}"

    if @chat.save
      create_initial_participants
      render json: @chat, status: :created
    else
      Rails.logger.error "Chat save failed: #{@chat.errors.full_messages}"
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
    # Allow recipient_id both nested and at top level for flexibility
    permitted_params = params.require(:chat).permit(
      :chat_type,
      :title,
      :recipient_id,
      :order_id,
      participant_ids: []
    )

    # If recipient_id is at the top level, merge it in
    if params[:recipient_id].present? && permitted_params[:recipient_id].blank?
      permitted_params[:recipient_id] = params[:recipient_id]
    end

    permitted_params
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
