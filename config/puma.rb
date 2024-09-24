# config/puma.rb

# Set the number of threads to use.
max_threads_count = ENV.fetch("RAILS_MAX_THREADS") { 5 }
min_threads_count = ENV.fetch("RAILS_MIN_THREADS") { max_threads_count }
threads min_threads_count, max_threads_count

# Specifies the port Puma will listen on. In production, you might use a reverse proxy (like Nginx),
# so the port might differ from development (e.g., 8080).
bind "tcp://0.0.0.0:3000"

# Specifies the environment. Ensure this is set to `production` in a production environment.
environment ENV.fetch("RAILS_ENV") { "production" }

# Specifies the PID file Puma will use.
pidfile ENV.fetch("PIDFILE") { "tmp/pids/server.pid" }

# Specifies the number of workers (forked processes). You can adjust this based on server capacity.
# Workers allow multi-process parallelization.
workers ENV.fetch("WEB_CONCURRENCY") { 2 }

# Preload the application before forking to use less memory (Copy On Write).
preload_app!

# Daemonize mode: Puma runs in the background.
daemonize ENV.fetch("PUMA_DAEMONIZE") { true }

# Allow Puma to be restarted by `rails restart` command.
plugin :tmp_restart

# Before forking, disconnect the database to avoid connection sharing.
before_fork do
  ActiveRecord::Base.connection_pool.disconnect! if defined?(ActiveRecord)
end

# After forking, re-establish database connections.
on_worker_boot do
  ActiveRecord::Base.establish_connection if defined?(ActiveRecord)
end

# Specifies log output for Puma.
stdout_redirect 'log/puma.stdout.log', 'log/puma.stderr.log', true
