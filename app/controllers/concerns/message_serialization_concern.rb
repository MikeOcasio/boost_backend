# frozen_string_literal: true

module MessageSerializationConcern
  extend ActiveSupport::Concern

  private

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

  def serialize_user(user)
    {
      id: user.id,
      first_name: user.first_name,
      last_name: user.last_name,
      email: user.email,
      role: user.role,
      image_url: user.image_url
    }
  end
end
