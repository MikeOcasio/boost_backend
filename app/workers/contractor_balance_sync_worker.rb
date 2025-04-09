# app/workers/contractor_balance_sync_worker.rb
class ContractorBalanceSyncWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'default', retry: 3

  def perform
    Contractor.where.not(stripe_account_id: nil).find_each do |contractor|
      contractor.sync_balance!
    rescue => e
      Rails.logger.error("Balance sync failed for Contractor #{contractor.id}: #{e.message}")
    end
  end
end
