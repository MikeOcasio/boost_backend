module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = find_verified_user
    end

    private

    def find_verified_user
      token = request.headers[:HTTP_AUTHORIZATION]&.split(' ')&.last
      if token
        jwt_payload = JWT.decode(
          token,
          Rails.application.credentials.devise_jwt_secret_key,
          true,
          { algorithm: 'HS256' }
        )
        User.find(jwt_payload[0]['sub'])
      else
        reject_unauthorized_connection
      end
    rescue JWT::DecodeError, ActiveRecord::RecordNotFound
      reject_unauthorized_connection
    end
  end
end
