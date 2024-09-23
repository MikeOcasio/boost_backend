# config/initializers/encryption.rb
Rails.application.configure do
  config.active_record.encryption.primary_key = Rails.application.credentials.dig(:encryption, :primary_key)
  config.active_record.encryption.secondary_key = Rails.application.credentials.dig(:encryption, :secondary_key)
end
