class ChatChannel < ApplicationCable::Channel
  include MessageSerializationConcern

  def subscribed
    @chat = Chat.find(params[:chat_id])

    # Check if the current user is a participant in this chat
    unless @chat.chat_participants.exists?(user_id: current_user.id)
      reject
      return
    end

    stream_for @chat
    Rails.logger.info "User #{current_user.id} subscribed to chat #{@chat.id}"

    # Notify other participants that user came online
    broadcast_user_status('online')
  end

  def unsubscribed
    Rails.logger.info "User #{current_user.id} unsubscribed from chat channel"

    # Notify other participants that user went offline
    broadcast_user_status('offline') if @chat

    stop_all_streams
  end

  # Handle sending messages via WebSocket
  def send_message(data)
    return unless @chat
    return transmit_error('Missing message content') if data['content'].blank?

    message = @chat.messages.build(
      content: data['content'].strip,
      sender: current_user
    )

    if message.save
      # Message will be broadcast via the after_create_commit callback in the Message model
      Rails.logger.info "Message sent via WebSocket by user #{current_user.id} in chat #{@chat.id}"

      # Send success confirmation to sender
      transmit({
                 type: 'message_sent',
                 message_id: message.id,
                 timestamp: Time.current
               })
    else
      transmit_error('Failed to send message', message.errors.full_messages)
    end
  end

  # Handle typing indicators
  def typing(data)
    return unless @chat

    ChatWebSocketService.broadcast_typing_indicator(@chat, current_user, data['is_typing'])
  end

  # Mark messages as read
  def mark_as_read(data)
    return unless @chat

    message_ids = data['message_ids'] || []
    return if message_ids.empty?

    # Only mark messages as read that weren't sent by the current user
    updated_count = @chat.messages.where(id: message_ids).where.not(sender: current_user).update_all(read: true)

    return unless updated_count > 0

    # Use the service to broadcast read receipts
    ChatWebSocketService.broadcast_read_receipts(@chat, message_ids, current_user)
  end

  # Load message history (for pagination)
  def load_messages(data)
    return unless @chat

    page = [data['page'].to_i, 1].max
    per_page = [[data['per_page'].to_i, 50].min, 10].max # Between 10 and 50

    messages = @chat.messages
                    .includes(:sender)
                    .order(created_at: :desc)
                    .limit(per_page)
                    .offset((page - 1) * per_page)

    messages_data = messages.reverse.map do |message|
      serialize_message(message)
    end

    transmit({
               type: 'message_history',
               messages: messages_data,
               page: page,
               per_page: per_page,
               has_more: messages.count == per_page
             })
  end

  private

  def broadcast_user_status(status)
    ChatWebSocketService.broadcast_user_status(@chat, current_user, status)
  end

  def transmit_error(message, details = [])
    transmit({
               type: 'error',
               message: message,
               details: details,
               timestamp: Time.current
             })
  end

  def serialize_message(message)
    {
      id: message.id,
      content: message.content,
      created_at: message.created_at,
      updated_at: message.updated_at,
      read: message.read,
      sender: serialize_user(message.sender)
    }
  end
end
