class Api::ChatWebSocketController < ApplicationController
  before_action :authenticate_user!

  # Get WebSocket connection info for a chat
  def connection_info
    chat = Chat.find(params[:id])

    unless chat.chat_participants.exists?(user_id: current_user.id)
      render json: { error: 'You are not a participant in this chat' }, status: :forbidden
      return
    end

    # Build WebSocket URL with authentication parameters
    base_websocket_url = Rails.application.config.action_cable.url || "ws://#{request.host}:#{request.port}/cable"
    websocket_url_with_params = "#{base_websocket_url}?user_id=#{current_user.id}&chat_id=#{chat.id}"

    render json: {
      chat_id: chat.id,
      websocket_url: websocket_url_with_params,
      user_id: current_user.id, # For reference
      user: {
        id: current_user.id,
        first_name: current_user.first_name,
        last_name: current_user.last_name,
        role: current_user.role,
        image_url: current_user.image_url
      }
    }, status: :ok
  end

  # Get all active WebSocket connections for a chat (admin only)
  def active_connections
    return render json: { error: 'Unauthorized' }, status: :unauthorized unless current_user.admin?

    chat = Chat.find(params[:chat_id])

    # This would require implementing connection tracking
    # For now, return a placeholder response
    render json: {
      chat_id: chat.id,
      active_connections: 0, # Would implement actual connection tracking
      message: 'Connection tracking not yet implemented'
    }, status: :ok
  end

  # Broadcast admin message to a chat
  def broadcast_admin_message
    return render json: { error: 'Unauthorized' }, status: :unauthorized unless current_user.admin?

    chat = Chat.find(params[:chat_id])
    message = params[:message]

    ChatWebSocketService.broadcast_system_message(chat, 'admin_announcement', {
                                                    message: message,
                                                    admin: {
                                                      id: current_user.id,
                                                      name: "#{current_user.first_name} #{current_user.last_name}"
                                                    }
                                                  })

    render json: { message: 'Admin message broadcasted successfully' }, status: :ok
  end

  # Force disconnect all users from a chat (admin only)
  def force_disconnect_all
    return render json: { error: 'Unauthorized' }, status: :unauthorized unless current_user.admin?

    chat = Chat.find(params[:chat_id])

    ChatWebSocketService.broadcast_system_message(chat, 'force_disconnect', {
                                                    reason: params[:reason] || 'Administrative action',
                                                    admin: {
                                                      id: current_user.id,
                                                      name: "#{current_user.first_name} #{current_user.last_name}"
                                                    }
                                                  })

    render json: { message: 'Force disconnect broadcasted to all participants' }, status: :ok
  end
end
