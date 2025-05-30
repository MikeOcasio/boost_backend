FactoryBot.define do
  factory :contractor do
    user { nil }
    last_payout_requested_at { "2025-05-12 16:55:55" }
    available_balance { 100.0 }
    pending_balance { 50.0 }
    total_earned { 150.0 }
    stripe_account_id { 'acct_test123' }
    last_withdrawal_at { 8.days.ago } # Past the 7-day cooldown
  end
end
