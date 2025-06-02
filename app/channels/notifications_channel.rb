class NotificationsChannel < ApplicationCable::Channel
  def subscribed
    user_id = params[:user_id]

    Rails.logger.info "User #{user_id} attempting to subscribe to notifications"

    begin
      # Verify user authentication - in ActionCable, we need to check the connection
      if current_user&.id == user_id.to_i
        # Subscribe to user-specific notifications stream
        stream_from "notifications_user_#{user_id}"
        Rails.logger.info "User #{user_id} successfully subscribed to notifications"

        # Send welcome message and current unread count
        unread_count = get_total_unread_count(user_id)
        transmit({
                   type: 'welcome',
                   message: 'Connected to notifications',
                   unread_count: unread_count,
                   timestamp: Time.current
                 })
      else
        Rails.logger.warn "User #{user_id} denied access to notifications - authentication failed"
        reject
      end
    rescue StandardError => e
      Rails.logger.error "Error in NotificationsChannel subscription: #{e.message}"
      reject
    end
  end

  def unsubscribed
    Rails.logger.info 'User unsubscribed from notifications channel'
    stop_all_streams
  end

  def receive(data)
    Rails.logger.info "Received data in NotificationsChannel: #{data}"

    case data['type']
    when 'mark_notifications_read'
      handle_mark_notifications_read(data)
    when 'get_unread_count'
      handle_get_unread_count(data)
    else
      Rails.logger.info "Unknown notification message type: #{data['type']}"
    end
  end

  private

  def handle_mark_notifications_read(data)
    user_id = current_user&.id
    return unless user_id

    notification_ids = data['notification_ids'] || []
    if notification_ids.any?
      # Mark specific notifications as read
      Notification.where(id: notification_ids, user_id: user_id)
                  .update_all(status: 'read')
    else
      # Mark all notifications as read for this user
      Notification.where(user_id: user_id, status: 'unread')
                  .update_all(status: 'read')
    end

    # Send updated unread count
    unread_count = get_total_unread_count(user_id)
    transmit({
               type: 'notifications_marked_read',
               unread_count: unread_count,
               timestamp: Time.current
             })
  end

  def handle_get_unread_count(_data)
    user_id = current_user&.id
    return unless user_id

    unread_count = get_total_unread_count(user_id)
    transmit({
               type: 'unread_count_update',
               unread_count: unread_count,
               timestamp: Time.current
             })
  end

  def get_total_unread_count(user_id)
    # Count unread messages across all chats for this user
    Message.joins(:chat)
           .joins('INNER JOIN chat_participants cp ON cp.chat_id = chats.id')
           .where('cp.user_id = ? AND messages.sender_id != ? AND messages.read = false',
                  user_id, user_id)
           .count
  end
end
