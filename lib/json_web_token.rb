# app/lib/json_web_token.rb

class JsonWebToken
  # Secret key for encoding and decoding tokens
  SECRET_KEY = Rails.application.credentials.secret_key_base

  # Encode a payload into a JWT
  def self.encode(payload, exp = 24.hours.from_now)
    payload[:exp] = exp.to_i
    JWT.encode(payload, SECRET_KEY)
  end

  # Decode a JWT and return the payload
  def self.decode(token)
    decoded = JWT.decode(token, SECRET_KEY, true, { algorithm: 'HS256' })
    decoded[0] # Return the payload
  rescue JWT::DecodeError => e
    # Handle the error as needed (log it, re-raise it, etc.)
    Rails.logger.error "JWT Decode Error: #{e.message}"
    nil
  end
end
