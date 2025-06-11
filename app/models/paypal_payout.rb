class PaypalPayout < ApplicationRecord
  belongs_to :contractor

  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :status, inclusion: { in: %w[pending processing success failed] }
  validates :contractor_id, presence: true

  scope :pending, -> { where(status: 'pending') }
  scope :processing, -> { where(status: 'processing') }
  scope :successful, -> { where(status: 'success') }
  scope :failed, -> { where(status: 'failed') }

  def mark_as_processing!(batch_id, item_id)
    update!(
      status: 'processing',
      paypal_payout_batch_id: batch_id,
      paypal_payout_item_id: item_id
    )
  end

  def mark_as_successful!(response_data = {})
    update!(
      status: 'success',
      paypal_response: response_data
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
end
