# app/workers/payout_status_sync_worker.rb
class PayoutStatusSyncWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'default', retry: 3

  def perform
    # Sync status of recent payouts (last 7 days)
    Payout.where('created_at > ?', 7.days.ago)
          .where.not(status: ['paid', 'failed', 'canceled'])
          .find_each do |payout|
      payout.sync_status!
    rescue => e
      Rails.logger.error("Payout status sync failed for Payout #{payout.id}: #{e.message}")
    end
  end
end
