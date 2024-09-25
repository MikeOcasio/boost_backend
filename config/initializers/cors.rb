Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins '*'  # Add trusted origins (Next.js frontend and Rails server)

    resource '*',
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      expose: ['X-CSRF-Token'],  # Expose the CSRF token in the response headers
      credentials: true  # Allow cookies and credentials (for sessions or auth)
  end
end
