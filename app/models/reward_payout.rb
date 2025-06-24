class RewardPayout < ApplicationRecord
  belongs_to :user_reward
  belongs_to :user

  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :status, inclusion: { in: %w[pending processing success failed] }
  validates :payout_type, inclusion: { in: %w[referral completion] }
  validates :recipient_email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true

  scope :pending, -> { where(status: 'pending') }
  scope :processing, -> { where(status: 'processing') }
  scope :successful, -> { where(status: 'success') }
  scope :failed, -> { where(status: 'failed') }
  scope :referral_payouts, -> { where(payout_type: 'referral') }
  scope :completion_payouts, -> { where(payout_type: 'completion') }

  def mark_as_processing!(batch_id, item_id)
    update!(
      status: 'processing',
      paypal_payout_batch_id: batch_id,
      paypal_payout_item_id: item_id,
      processed_at: Time.current
    )
  end

  def mark_as_successful!(response_data = {})
    update!(
      status: 'success',
      paypal_response: response_data
    )

    # Mark the associated user reward as paid
    user_reward.update!(
      status: 'paid',
      paid_at: Time.current
    )
  end

  def mark_as_failed!(reason, response_data = {})
    update!(
      status: 'failed',
      failure_reason: reason,
      paypal_response: response_data
    )
  end

  def pending?
    status == 'pending'
  end

  def processing?
    status == 'processing'
  end

  def successful?
    status == 'success'
  end

  def failed?
    status == 'failed'
  end

  def title
    if payout_type == 'referral'
      UserReward::REFERRAL_THRESHOLDS.dig(user_reward.points, :title) || 'Referral Reward'
    else
      UserReward::COMPLETION_THRESHOLDS.dig(user_reward.points, :title) || 'Completion Reward'
    end
  end
end
