# frozen_string_literal: true

class ChatWebSocketService
  class << self
    # Broadcast system messages (e.g., user joined, left, status changes)
    def broadcast_system_message(chat, message_type, data = {})
      ChatChannel.broadcast_to(chat, {
                                 type: 'system_message',
                                 message_type: message_type,
                                 data: data,
                                 timestamp: Time.current
                               })
    end

    # Broadcast chat status changes
    def broadcast_chat_status_change(chat, old_status, new_status)
      ChatChannel.broadcast_to(chat, {
                                 type: 'chat_status_change',
                                 old_status: old_status,
                                 new_status: new_status,
                                 timestamp: Time.current
                               })
    end

    # Broadcast participant changes
    def broadcast_participant_added(chat, user)
      ChatChannel.broadcast_to(chat, {
                                 type: 'participant_added',
                                 participant: serialize_user(user),
                                 timestamp: Time.current
                               })
    end

    def broadcast_participant_removed(chat, user)
      ChatChannel.broadcast_to(chat, {
                                 type: 'participant_removed',
                                 participant_id: user.id,
                                 participant_name: "#{user.first_name} #{user.last_name}",
                                 timestamp: Time.current
                               })
    end

    # Broadcast message deletions
    def broadcast_message_deleted(chat, message_id, deleted_by_user)
      ChatChannel.broadcast_to(chat, {
                                 type: 'message_deleted',
                                 message_id: message_id,
                                 deleted_by: serialize_user(deleted_by_user),
                                 timestamp: Time.current
                               })
    end

    # Broadcast message updates
    def broadcast_message_updated(chat, message)
      ChatChannel.broadcast_to(chat, {
                                 type: 'message_updated',
                                 id: message.id,
                                 content: message.content,
                                 updated_at: message.updated_at,
                                 updated_by: serialize_user(message.sender),
                                 timestamp: Time.current
                               })
    end

    # Broadcast file attachments
    def broadcast_file_attachment(chat, attachment_data)
      ChatChannel.broadcast_to(chat, {
                                 type: 'file_attachment',
                                 **attachment_data,
                                 timestamp: Time.current
                               })
    end

    # Broadcast notification when someone mentions a user
    def broadcast_user_mention(chat, mentioned_user, message)
      ChatChannel.broadcast_to(chat, {
                                 type: 'user_mention',
                                 mentioned_user: serialize_user(mentioned_user),
                                 message_id: message.id,
                                 sender: serialize_user(message.sender),
                                 timestamp: Time.current
                               })
    end

    # Broadcast typing indicators (alternative method to ChatChannel#typing)
    def broadcast_typing_indicator(chat, user, is_typing)
      ChatChannel.broadcast_to(chat, {
                                 type: 'typing',
                                 user_id: user.id,
                                 user_name: "#{user.first_name} #{user.last_name}",
                                 is_typing: is_typing,
                                 timestamp: Time.current
                               })
    end

    # Broadcast user status changes (online/offline)
    def broadcast_user_status(chat, user, status)
      ChatChannel.broadcast_to(chat, {
                                 type: 'user_status',
                                 user_id: user.id,
                                 user_name: "#{user.first_name} #{user.last_name}",
                                 status: status,
                                 timestamp: Time.current
                               })
    end

    # Broadcast read receipts
    def broadcast_read_receipts(chat, message_ids, read_by_user)
      ChatChannel.broadcast_to(chat, {
                                 type: 'messages_read',
                                 message_ids: message_ids,
                                 read_by_user_id: read_by_user.id,
                                 read_by_name: "#{read_by_user.first_name} #{read_by_user.last_name}",
                                 timestamp: Time.current
                               })
    end

    # Broadcast error messages to specific users
    def broadcast_error_to_user(chat, user, error_message, error_details = {})
      # NOTE: This would require more sophisticated targeting
      # For now, we'll use transmit in the channel instead
      {
        type: 'error',
        message: error_message,
        details: error_details,
        timestamp: Time.current
      }
    end

    private

    # Helper method to serialize user data consistently
    def serialize_user(user)
      return nil unless user

      {
        id: user.id,
        first_name: user.first_name,
        last_name: user.last_name,
        name: "#{user.first_name} #{user.last_name}",
        email: user.email,
        role: user.role,
        image_url: user.image_url
      }
    end
  end
end
