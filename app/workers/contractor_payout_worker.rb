# app/workers/contractor_payout_worker.rb
class ContractorPayoutWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'default', retry: 3

  PAYOUT_THRESHOLD = 5000  # $50.00

  def perform
    Contractor.where("available_balance >= ?", PAYOUT_THRESHOLD)
              .where.not(stripe_account_id: nil)
              .find_each do |contractor|
      contractor.request_payout!
    rescue => e
      Rails.logger.error("Automated payout failed for Contractor #{contractor.id}: #{e.message}")
    end
  end
end
