class OrderRejection < ApplicationRecord
  belongs_to :order
  belongs_to :admin_user, class_name: 'User'

  validates :rejection_type, presence: true, inclusion: { in: %w[payment_rejection dispute_rejection] }
  validates :reason, presence: true
  validates :order_id, presence: true
  validates :admin_user_id, presence: true

  scope :payment_rejections, -> { where(rejection_type: 'payment_rejection') }
  scope :dispute_rejections, -> { where(rejection_type: 'dispute_rejection') }
  scope :recent, ->(days = 30) { where('created_at >= ?', days.days.ago) }

  def payment_rejection?
    rejection_type == 'payment_rejection'
  end

  def dispute_rejection?
    rejection_type == 'dispute_rejection'
  end

  def self.rejection_analytics(days = 30)
    rejections = recent(days)

    {
      total_rejections: rejections.count,
      payment_rejections: rejections.payment_rejections.count,
      dispute_rejections: rejections.dispute_rejections.count,
      rejection_rate: calculate_rejection_rate(days),
      top_rejection_reasons: top_rejection_reasons(days),
      rejections_by_admin: rejections_by_admin(days)
    }
  end

  private

  def self.calculate_rejection_rate(days)
    total_reviews = Order.where('admin_reviewed_at >= ?', days.days.ago).count
    total_rejections = recent(days).count

    return 0 if total_reviews.zero?

    ((total_rejections.to_f / total_reviews) * 100).round(2)
  end

  def self.top_rejection_reasons(days, limit = 5)
    recent(days)
      .group(:reason)
      .count
      .sort_by { |_, count| -count }
      .first(limit)
      .to_h
  end

  def self.rejections_by_admin(days)
    recent(days)
      .joins(:admin_user)
      .group('users.first_name', 'users.last_name')
      .count
      .transform_keys { |first, last| "#{first} #{last}" }
  end
end
