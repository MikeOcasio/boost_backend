# Scheduled Jobs Configuration
#
# This file sets up recurring jobs for the payment system.
# You can integrate this with cron, whenever gem, or Sidekiq's recurring jobs.
#
# Example cron jobs to add to your system:
#
# # Run daily at 2 AM to move pending balances
# 0 2 * * * cd /path/to/your/app && RAILS_ENV=production bundle exec rails runner "MovePendingBalancesJob.perform_later"
#
# For development/testing, you can run these manually in the Rails console:
# MovePendingBalancesJob.perform_now

Rails.logger.info "Payment system jobs configured. Set up cron jobs or recurring job scheduler for production."
