class ChatChannel < ApplicationCable::Channel
  def subscribed
    chat_id = params[:chat_id]
    user_id = params[:user_id]
    
    Rails.logger.info "User #{user_id} attempting to subscribe to chat #{chat_id}"
    
    begin
      # Find the chat and verify user has access
      @chat = Chat.find(chat_id)
      
      # Check if the current user is a participant in this chat
      unless @chat.chat_participants.exists?(user_id: user_id)
        Rails.logger.warn "User #{user_id} denied access to chat #{chat_id}"
        reject
        return
      end

      # Subscribe to the chat stream
      stream_from "chat_#{@chat.id}"
      Rails.logger.info "User #{user_id} successfully subscribed to chat_#{@chat.id}"
      
      # Send welcome message to confirm connection
      transmit({
        type: 'welcome',
        message: 'Connected to chat',
        chat_id: @chat.id,
        timestamp: Time.current
      })

    rescue ActiveRecord::RecordNotFound
      Rails.logger.error "Chat #{chat_id} not found"
      reject
    rescue => e
      Rails.logger.error "Error in ChatChannel subscription: #{e.message}"
      reject
    end
  end

  def unsubscribed
    if @chat
      Rails.logger.info "User unsubscribed from chat #{@chat.id}"
    else
      Rails.logger.info "User unsubscribed from chat channel"
    end
    stop_all_streams
  end

  def receive(data)
    Rails.logger.info "Received data in ChatChannel: #{data}"
    
    case data['type']
    when 'join_chat'
      Rails.logger.info "User joining chat: #{data['chat_id']}"
      # Handle join chat if needed
      
    when 'send_message'
      handle_send_message(data)
      
    when 'typing'
      handle_typing(data)
      
    when 'mark_as_read'
      handle_mark_as_read(data)
      
    when 'message_sent'
      Rails.logger.info "Message sent confirmation: #{data['message_id']}"
      # Handle message sent confirmation if needed
      
    else
      Rails.logger.info "Unknown message type: #{data['type']}"
    end
  end

  private

  def handle_send_message(data)
    return unless @chat
    return transmit_error('Missing message content') if data['content'].blank?

    message = @chat.messages.build(
      content: data['content'].strip,
      sender_id: data['user_id']
    )

    if message.save
      # Prepare message data for broadcasting
      message_data = {
        id: message.id,
        content: message.content,
        created_at: message.created_at,
        read: message.read,
        chat_id: message.chat_id,
        sender: {
          id: message.sender.id,
          first_name: message.sender.first_name,
          last_name: message.sender.last_name,
          role: message.sender.role,
          image_url: message.sender.image_url
        }
      }

      # Broadcast to all subscribers of this chat
      ActionCable.server.broadcast("chat_#{@chat.id}", {
        type: 'new_message',
        message: message_data
      })

      Rails.logger.info "Message sent via WebSocket and broadcasted to chat_#{@chat.id}"

      # Send success confirmation to sender
      transmit({
        type: 'message_sent',
        message_id: message.id,
        temp_id: data['temp_id'],
        message: message_data,
        timestamp: Time.current
      })
    else
      transmit_error('Failed to send message', message.errors.full_messages)
    end
  end

  def handle_typing(data)
    return unless @chat

    # Broadcast typing indicator to other participants
    ActionCable.server.broadcast("chat_#{@chat.id}", {
      type: 'typing',
      user_id: data['user_id'],
      is_typing: data['is_typing'],
      timestamp: Time.current
    })
  end

  def handle_mark_as_read(data)
    return unless @chat

    message_ids = data['message_ids'] || []
    return if message_ids.empty?

    # Only mark messages as read that weren't sent by the current user
    updated_count = @chat.messages
                         .where(id: message_ids)
                         .where.not(sender_id: data['user_id'])
                         .update_all(read: true)

    if updated_count > 0
      # Broadcast read receipts to other participants
      ActionCable.server.broadcast("chat_#{@chat.id}", {
        type: 'messages_read',
        message_ids: message_ids,
        read_by_user_id: data['user_id'],
        timestamp: Time.current
      })
    end
  end

  def transmit_error(message, details = [])
    transmit({
      type: 'error',
      message: message,
      details: details,
      timestamp: Time.current
    })
  end
end
