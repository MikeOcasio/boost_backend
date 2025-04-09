# app/models/payout.rb
class Payout < ApplicationRecord
  belongs_to :contractor

  validates :stripe_payout_id, presence: true, uniqueness: true
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :status, presence: true

  def sync_status!
    return unless stripe_payout_id.present?

    begin
      stripe_payout = Stripe::Payout.retrieve(
        stripe_payout_id,
        { stripe_account: contractor.stripe_account_id }
      )

      update!(
        status: stripe_payout.status,
        metadata: stripe_payout.to_h
      )
    rescue => e
      Rails.logger.error("Payout status sync failed: #{e.message}")
      false
    end
  end
end
