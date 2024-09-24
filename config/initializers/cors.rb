Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins 'localhost:3006'

    resource '*',
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      expose: ['X-CSRF-Token'],
      credentials: true
  end
end
