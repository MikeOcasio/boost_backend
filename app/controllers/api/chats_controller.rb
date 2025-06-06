class Api::ChatsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_chat,
                only: %i[show update archive close reopen chat_states mark_messages_read set_typing_status unread_count
                         send_message]
  before_action :verify_chat_access,
                only: %i[show update archive close reopen chat_states mark_messages_read set_typing_status unread_count
                         send_message]

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
        reference_id: chat.reference_id,
        reopen_count: chat.reopen_count,
        closed_at: chat.closed_at,
        reopened_at: chat.reopened_at,
        created_at: chat.created_at,
        updated_at: chat.updated_at,
        can_close: chat.can_close?,
        can_reopen: chat.can_reopen?,
        is_active: chat.active?,
        is_closed: chat.closed?,
        is_locked: chat.locked?,
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
      reference_id: @chat.reference_id,
      reopen_count: @chat.reopen_count,
      closed_at: @chat.closed_at,
      reopened_at: @chat.reopened_at,
      created_at: @chat.created_at,
      updated_at: @chat.updated_at,
      can_close: @chat.can_close?,
      can_reopen: @chat.can_reopen?,
      is_active: @chat.active?,
      is_closed: @chat.closed?,
      is_locked: @chat.locked?,
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

  def close
    unless @chat.can_close?
      render json: { error: 'Chat cannot be closed in its current state' }, status: :unprocessable_entity
      return
    end

    if @chat.close!
      # Broadcast chat closure to all participants
      broadcast_chat_state_change('chat_closed', {
                                    closed_at: @chat.closed_at,
                                    closed_by: current_user.id
                                  })

      render json: format_chat_response(@chat), status: :ok
    else
      render json: @chat.errors, status: :unprocessable_entity
    end
  end

  def reopen
    unless @chat.can_reopen?
      render json: { error: 'Chat cannot be reopened' }, status: :unprocessable_entity
      return
    end

    if @chat.reopen!
      # Broadcast chat reopening to all participants
      broadcast_chat_state_change('chat_reopened', {
                                    reopened_at: @chat.reopened_at,
                                    reopen_count: @chat.reopen_count,
                                    reopened_by: current_user.id
                                  })

      render json: format_chat_response(@chat), status: :ok
    else
      render json: @chat.errors, status: :unprocessable_entity
    end
  end

  def send_message
    @chat = Chat.find(params[:id])

    # Verify user has access to this chat
    unless @chat.chat_participants.exists?(user_id: current_user.id)
      render json: { error: 'Access denied' }, status: :forbidden
      return
    end

    # Check if chat is active (not closed or locked)
    unless @chat.active?
      render json: { error: 'Cannot send messages to an inactive chat',
                     status: @chat.status }, status: :unprocessable_entity
      return
    end

    @message = @chat.messages.build(message_params)
    @message.sender = current_user

    if @message.save
      # Prepare message data for broadcasting
      message_data = {
        id: @message.id,
        content: @message.content,
        created_at: @message.created_at,
        read: @message.read,
        chat_id: @message.chat_id,
        sender: {
          id: @message.sender.id,
          first_name: @message.sender.first_name,
          last_name: @message.sender.last_name,
          role: @message.sender.role,
          image_url: @message.sender.image_url
        }
      }

      # Broadcast via WebSocket if available
      begin
        # Use ActionCable to broadcast to the chat channel
        ActionCable.server.broadcast("chat_#{@chat.id}", {
                                       type: 'new_message',
                                       message: message_data
                                     })

        Rails.logger.info "Successfully broadcasted message to chat_#{@chat.id}"
      rescue StandardError => e
        Rails.logger.error "Failed to broadcast message: #{e.message}"
      end

      # Send notifications to other participants
      begin
        other_participants = @chat.participants.where.not(id: current_user.id)

        other_participants.each do |participant|
          # Broadcast notification to each participant's notification channel
          ActionCable.server.broadcast("notifications_user_#{participant.id}", {
                                         type: 'new_message_notification',
                                         message: message_data,
                                         chat: {
                                           id: @chat.id,
                                           title: @chat.title,
                                           chat_type: @chat.chat_type,
                                           ticket_number: @chat.ticket_number
                                         },
                                         unread_count: get_user_total_unread_count(participant.id),
                                         timestamp: Time.current
                                       })
        end

        Rails.logger.info "Successfully sent notifications to #{other_participants.count} participants"
      rescue StandardError => e
        Rails.logger.error "Failed to send notifications: #{e.message}"
      end

      render json: {
        message: message_data
      }, status: :created
    else
      render json: { errors: @message.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def new_messages
    @chat = Chat.find(params[:id])

    unless @chat.chat_participants.exists?(user_id: current_user.id)
      render json: { error: 'Access denied' }, status: :forbidden
      return
    end

    last_message_id = params[:last_message_id].to_i

    new_messages = @chat.messages.includes(:sender)
                        .where('id > ?', last_message_id)
                        .order(created_at: :asc)
                        .map do |message|
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

    render json: { messages: new_messages }, status: :ok
  end

  def connection_info
    @chat = Chat.find(params[:id])

    # Verify user has access to this chat
    unless @chat.chat_participants.exists?(user_id: current_user.id)
      render json: { error: 'Access denied' }, status: :forbidden
      return
    end

    # Return WebSocket URL and channel info
    websocket_url = Rails.application.config.action_cable.url || 'ws://localhost:3000/cable'

    render json: {
      websocket_url: websocket_url,
      channel: 'ChatChannel',
      chat_id: @chat.id,
      user_id: current_user.id
    }
  end

  def chat_states
    # Get comprehensive chat state information for the frontend
    render json: get_chat_states(@chat), status: :ok
  end

  def mark_messages_read
    message_ids = params[:message_ids] || []

    if message_ids.empty?
      render json: { error: 'No message IDs provided' }, status: :unprocessable_entity
      return
    end

    # Only mark messages as read that weren't sent by the current user
    updated_count = @chat.messages
                         .where(id: message_ids)
                         .where.not(sender_id: current_user.id)
                         .update_all(read: true)

    if updated_count > 0
      # Broadcast read receipts to other participants via WebSocket
      broadcast_chat_state_change('messages_read', {
                                    message_ids: message_ids,
                                    read_by_user_id: current_user.id
                                  })

      # Also broadcast notification update to the current user's notification channel
      begin
        ActionCable.server.broadcast("notifications_user_#{current_user.id}", {
                                       type: 'messages_marked_read',
                                       chat_id: @chat.id,
                                       marked_count: updated_count,
                                       unread_count: get_user_total_unread_count(current_user.id),
                                       timestamp: Time.current
                                     })
      rescue StandardError => e
        Rails.logger.error "Failed to broadcast notification update: #{e.message}"
      end
    end

    render json: {
      messages_marked_read: updated_count,
      updated_message_ids: message_ids
    }, status: :ok
  end

  def set_typing_status
    is_typing = params[:is_typing] == true || params[:is_typing] == 'true'

    # Broadcast typing status to other participants
    broadcast_chat_state_change('typing', {
                                  user_id: current_user.id,
                                  is_typing: is_typing,
                                  user_name: "#{current_user.first_name} #{current_user.last_name}"
                                })

    render json: {
      typing_status_set: true,
      is_typing: is_typing
    }, status: :ok
  end

  def unread_count
    # Count unread messages for current user in this chat
    unread_count = @chat.messages
                        .where.not(sender_id: current_user.id)
                        .where(read: false)
                        .count

    render json: {
      unread_count: unread_count,
      chat_id: @chat.id
    }, status: :ok
  end

  def unread_messages
    # Get all unread messages across all chats for the current user
    chats_with_unread = Chat.includes(:messages, :participants, :initiator, :recipient)
                            .joins(:messages)
                            .where(id: accessible_chat_ids)
                            .where(messages: {
                                     sender_id: User.where.not(id: current_user.id),
                                     read: false
                                   })
                            .distinct

    unread_data = chats_with_unread.map do |chat|
      unread_messages = chat.messages.includes(:sender)
                            .where.not(sender_id: current_user.id)
                            .where(read: false)
                            .order(created_at: :desc)

      {
        chat_id: chat.id,
        chat_title: chat.title,
        chat_type: chat.chat_type,
        ticket_number: chat.ticket_number,
        unread_count: unread_messages.count,
        messages: unread_messages.map do |message|
          {
            id: message.id,
            content: message.content,
            created_at: message.created_at,
            sender: {
              id: message.sender.id,
              first_name: message.sender.first_name,
              last_name: message.sender.last_name,
              role: message.sender.role,
              image_url: message.sender.image_url
            }
          }
        end
      }
    end

    total_unread_count = unread_data.sum { |chat| chat[:unread_count] }

    render json: {
      total_unread_count: total_unread_count,
      chats: unread_data
    }, status: :ok
  end

  def mark_all_messages_read
    # Mark all unread messages as read for the current user across all their chats
    updated_count = 0

    accessible_chat_ids.each do |chat_id|
      chat = Chat.find(chat_id)
      count = chat.messages
                  .where.not(sender_id: current_user.id)
                  .where(read: false)
                  .update_all(read: true)
      updated_count += count

      # Broadcast read receipts to other participants if any messages were updated
      next unless count > 0

      message_ids = chat.messages
                        .where.not(sender_id: current_user.id)
                        .where(read: true)
                        .pluck(:id)

      # Broadcast via WebSocket if available
      begin
        ActionCable.server.broadcast("chat_#{chat_id}", {
                                       type: 'messages_read',
                                       message_ids: message_ids,
                                       read_by_user_id: current_user.id,
                                       timestamp: Time.current
                                     })
      rescue StandardError => e
        Rails.logger.error "Failed to broadcast read receipts: #{e.message}"
      end

      # Also broadcast to the user's notification channel
      begin
        ActionCable.server.broadcast("notifications_user_#{current_user.id}", {
                                       type: 'messages_marked_read',
                                       chat_id: chat_id,
                                       marked_count: count,
                                       timestamp: Time.current
                                     })
      rescue StandardError => e
        Rails.logger.error "Failed to broadcast notification update: #{e.message}"
      end
    end

    render json: {
      total_messages_marked_read: updated_count,
      timestamp: Time.current
    }, status: :ok
  end

  def all_chat_states
    # Get states for all chats the user has access to
    chat_ids = accessible_chat_ids
    chats_with_states = Chat.includes(:messages, :participants, :initiator, :recipient)
                            .where(id: chat_ids)
                            .map do |chat|
      get_chat_states(chat)
    end

    render json: { chats: chats_with_states }, status: :ok
  end

  def find_by_reference_id
    reference_id = params[:reference_id]

    if reference_id.blank?
      render json: { error: 'Reference ID is required' }, status: :unprocessable_entity
      return
    end

    chat = Chat.find_by(reference_id: reference_id)

    unless chat
      render json: { error: 'Chat not found with the provided reference ID' }, status: :not_found
      return
    end

    # Verify user has access to this chat
    unless chat.chat_participants.exists?(user_id: current_user.id)
      render json: { error: 'You do not have access to this chat' }, status: :forbidden
      return
    end

    render json: format_chat_response(chat), status: :ok
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

  def message_params
    params.require(:message).permit(:content)
  end

  def create_initial_participants
    ensure_chat_participants(@chat)
  end

  def accessible_chat_ids
    ChatParticipant.where(user_id: current_user.id).pluck(:chat_id)
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

  def broadcast_chat_state_change(event_type, additional_data = {})
    # Broadcast via WebSocket if available

    ActionCable.server.broadcast("chat_#{@chat.id}", {
                                   type: event_type,
                                   chat_id: @chat.id,
                                   status: @chat.status,
                                   **additional_data,
                                   timestamp: Time.current
                                 })

    Rails.logger.info "Successfully broadcasted #{event_type} to chat_#{@chat.id}"
  rescue StandardError => e
    Rails.logger.error "Failed to broadcast #{event_type}: #{e.message}"
  end

  def get_chat_states(chat)
    # Get current user's unread message count for this chat
    unread_count = chat.messages
                       .where.not(sender_id: current_user.id)
                       .where(read: false)
                       .count

    # Get the last message details
    last_message = chat.messages.includes(:sender).order(created_at: :desc).first

    # Get read receipts for recent messages (last 50)
    recent_messages = chat.messages.includes(:sender)
                          .order(created_at: :desc)
                          .limit(50)

    message_read_states = recent_messages.map do |message|
      {
        message_id: message.id,
        is_read: message.read,
        sent_by_current_user: message.sender_id == current_user.id,
        sender: {
          id: message.sender.id,
          name: "#{message.sender.first_name} #{message.sender.last_name}"
        }
      }
    end

    # Get participant info
    other_participants = chat.participants.where.not(id: current_user.id)

    {
      chat_id: chat.id,
      chat_status: chat.status,
      unread_count: unread_count,
      total_message_count: chat.messages.count,
      last_message: if last_message
                      {
                        id: last_message.id,
                        content: last_message.content,
                        created_at: last_message.created_at,
                        is_read: last_message.read,
                        sent_by_current_user: last_message.sender_id == current_user.id,
                        sender: {
                          id: last_message.sender.id,
                          name: "#{last_message.sender.first_name} #{last_message.sender.last_name}",
                          role: last_message.sender.role
                        }
                      }
                    else
                      nil
                    end,
      participants: other_participants.map do |participant|
        {
          id: participant.id,
          name: "#{participant.first_name} #{participant.last_name}",
          role: participant.role,
          image_url: participant.image_url,
          is_online: false # This could be enhanced with real online status
        }
      end,
      message_read_states: message_read_states,
      current_user_id: current_user.id,
      can_send_messages: chat.active?,
      lifecycle_info: {
        can_close: chat.can_close?,
        can_reopen: chat.can_reopen?,
        is_active: chat.active?,
        is_closed: chat.closed?,
        is_locked: chat.locked?,
        closed_at: chat.closed_at,
        reopened_at: chat.reopened_at,
        reopen_count: chat.reopen_count
      }
    }
  end

  def format_chat_response(chat)
    {
      id: chat.id,
      chat_type: chat.chat_type,
      title: chat.title,
      status: chat.status,
      ticket_number: chat.ticket_number,
      reference_id: chat.reference_id,
      reopen_count: chat.reopen_count,
      closed_at: chat.closed_at,
      reopened_at: chat.reopened_at,
      created_at: chat.created_at,
      updated_at: chat.updated_at,
      can_close: chat.can_close?,
      can_reopen: chat.can_reopen?,
      is_active: chat.active?,
      is_closed: chat.closed?,
      is_locked: chat.locked?
    }
  end

  def get_user_total_unread_count(user_id)
    # Count unread messages across all chats for a specific user
    Message.joins(:chat)
           .joins('INNER JOIN chat_participants cp ON cp.chat_id = chats.id')
           .where('cp.user_id = ? AND messages.sender_id != ? AND messages.read = false',
                  user_id, user_id)
           .count
  end
end
