class Api::ChatsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_chat, only: %i[show update archive]
  before_action :verify_chat_access, only: %i[show update archive]
  before_action :verify_chat_access, only: %i[show update archive]

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
    # Get messages with proper sender information
    messages = @chat.messages.includes(:sender).order(created_at: :asc).map do |message|
      {
        id: message.id,
        content: message.content,
        created_at: message.created_at,
        read: message.read,
        sender: {
          id: message.sender.id,
          first_name: message.sender.first_name,
          last_name: message.sender.last_name,
          role: message.sender.role,
          image_url: message.sender.image_url
        }
      }
    end

    chat_data = {
      id: @chat.id,
      chat_type: @chat.chat_type,
      title: @chat.title,
      status: @chat.status,
      ticket_number: @chat.ticket_number,
      created_at: @chat.created_at,
      updated_at: @chat.updated_at,
      initiator: {
        id: @chat.initiator.id,
        first_name: @chat.initiator.first_name,
        last_name: @chat.initiator.last_name,
        email: @chat.initiator.email,
        role: @chat.initiator.role,
        image_url: @chat.initiator.image_url
      },
      recipient: if @chat.recipient
                   {
                     id: @chat.recipient.id,
                     first_name: @chat.recipient.first_name,
                     last_name: @chat.recipient.last_name,
                     email: @chat.recipient.email,
                     role: @chat.recipient.role,
                     image_url: @chat.recipient.image_url
                   }
                 else
                   nil
                 end,
      participants: @chat.participants.map do |participant|
        {
          id: participant.id,
          first_name: participant.first_name,
          last_name: participant.last_name,
          email: participant.email,
          role: participant.role,
          image_url: participant.image_url
        }
      end,
      messages: messages
    }

    render json: chat_data, status: :ok
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

        # Ensure the existing chat has proper participants
        ensure_chat_participants(existing_chat)

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

  def verify_chat_access
    return if @chat.chat_participants.exists?(user_id: current_user.id)

    render json: { error: 'You do not have access to this chat' }, status: :forbidden
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
    ensure_chat_participants(@chat)
  end

  def accessible_chat_ids
    ChatParticipant.where(user_id: current_user.id).pluck(:chat_id)
  end

  def verify_chat_access
    return if accessible_chat_ids.include?(@chat.id)

    render json: { error: 'Access denied' }, status: :forbidden
  end

  def ensure_chat_participants(chat)
    # Check if participants exist, if not create them
    existing_participants = chat.chat_participants.pluck(:user_id)

    case chat.chat_type
    when 'direct', 'support'
      required_participants = [chat.initiator_id, chat.recipient_id].compact
      missing_participants = required_participants - existing_participants

      missing_participants.each do |user_id|
        Rails.logger.info "Adding missing participant #{user_id} to chat #{chat.id}"
        chat.chat_participants.create!(user_id: user_id)
      end
    when 'group'
      # For group chats, add all specified participants plus initiator
      required_participants = [chat.initiator_id]

      # Add participants from params if this is during creation
      if params[:chat]&.[](:participant_ids).present?
        required_participants += params[:chat][:participant_ids].map(&:to_i)
      end

      required_participants = required_participants.uniq
      missing_participants = required_participants - existing_participants

      missing_participants.each do |user_id|
        Rails.logger.info "Adding missing participant #{user_id} to group chat #{chat.id}"
        chat.chat_participants.create!(user_id: user_id)
      end
    end
  end
end
