class PaymentApproval < ApplicationRecord
  belongs_to :order
  belongs_to :admin_user, class_name: 'User', optional: true

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

  # Helper methods for the controller
  def user
    order.user
  end

  def skillmaster
    User.find(order.assigned_skill_master_id) if order.assigned_skill_master_id
  end

  def amount
    order.total_price
  end

  def skillmaster_earnings
    order.skillmaster_earned
  end

  def admin_notes
    notes
  end

  def approved_by
    admin_user
  end

  def rejected_by
    admin_user
  end
end
