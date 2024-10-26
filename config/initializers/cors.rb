Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins 'http://localhost:3006', 'http://18.222.197.122:3000' # Add trusted origins (Next.js frontend and Rails server)

    resource '*',
             headers: :any,
             methods: %i[get post put patch delete options head],
             expose: %w['Authorization' 'Uid'], # Combine all exposed headers in a single array
             credentials: true # Allow cookies and credentials (for sessions or auth)
  end
end
