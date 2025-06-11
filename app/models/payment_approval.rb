class PaymentApproval < ApplicationRecord
  belongs_to :order
  belongs_to :admin_user, class_name: 'User'

  validates :status, inclusion: { in: %w[pending approved rejected] }
  validates :order_id, uniqueness: true

  scope :pending, -> { where(status: 'pending') }
  scope :approved, -> { where(status: 'approved') }
  scope :rejected, -> { where(status: 'rejected') }

  def approve!(admin_user, notes = nil)
    update!(
      status: 'approved',
      admin_user: admin_user,
      notes: notes,
      approved_at: Time.current
    )
  end

  def reject!(admin_user, notes = nil)
    update!(
      status: 'rejected',
      admin_user: admin_user,
      notes: notes,
      rejected_at: Time.current
    )
  end

  def approved?
    status == 'approved'
  end

  def rejected?
    status == 'rejected'
  end

  def pending?
    status == 'pending'
  end
end
