module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = find_verified_user
    end

    private

    def find_verified_user
      user_id = request.params[:user_id]
      chat_id = request.params[:chat_id]

      return reject_unauthorized_connection unless user_id && chat_id

      user = User.find_by(id: user_id)
      chat = Chat.find_by(id: chat_id)

      return reject_unauthorized_connection unless user && chat

      # Verify user is a participant in the chat
      if chat.chat_participants.exists?(user_id: user.id)
        user
      else
        reject_unauthorized_connection
      end
    rescue ActiveRecord::RecordNotFound
      reject_unauthorized_connection
    end
  end
end
