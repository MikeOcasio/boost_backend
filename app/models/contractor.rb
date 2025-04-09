# app/models/contractor.rb
class Contractor < ApplicationRecord
  belongs_to :user
  has_many :payouts, dependent: :destroy

  validates :stripe_account_id, uniqueness: true, allow_nil: true

  def sync_balance!
    return unless stripe_account_id.present?

    begin
      balance = Stripe::Balance.retrieve(stripe_account: stripe_account_id)

      update!(
        available_balance: balance.available.first.amount,
        pending_balance: balance.pending.first.amount,
        last_synced_at: Time.current
      )
    rescue => e
      Rails.logger.error("Balance sync failed for Contractor #{id}: #{e.message}")
      false
    end
  end

  def request_payout!(amount = nil)
    return false unless stripe_account_id.present?
    return false if available_balance <= 0

    # Default to full available balance if no amount specified
    payout_amount = amount || available_balance

    begin
      stripe_payout = Stripe::Payout.create(
        {
          amount: payout_amount,
          currency: 'usd',
        },
        { stripe_account: stripe_account_id }
      )

      payouts.create!(
        stripe_payout_id: stripe_payout.id,
        amount: payout_amount,
        status: stripe_payout.status,
        metadata: stripe_payout.to_h
      )

      # Update local balance immediately for better UX
      # This will be corrected on next sync if needed
      self.available_balance -= payout_amount
      save!

      true
    rescue => e
      Rails.logger.error("Payout request failed for Contractor #{id}: #{e.message}")
      false
    end
  end
end


