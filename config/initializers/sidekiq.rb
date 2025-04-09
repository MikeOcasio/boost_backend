# config/initializers/sidekiq.rb

require 'sidekiq'
require 'sidekiq/web'
require 'sidekiq/cron/web' if defined?(Sidekiq::Cron)

redis_config = {
  url: Rails.application.credentials.dig(:redis, :url) || 'redis://localhost:6379/0',
  ssl_params: { verify_mode: OpenSSL::SSL::VERIFY_NONE }
}

Sidekiq.configure_server do |config|
  config.redis = redis_config

  # Load the schedule
  schedule_file = "config/schedule.yml"
  if File.exist?(schedule_file) && defined?(Sidekiq::Cron)
    Sidekiq::Cron::Job.load_from_hash YAML.load_file(schedule_file)
  end
end

Sidekiq.configure_client do |config|
  config.redis = redis_config
end
