class Review < ApplicationRecord
  belongs_to :user
  belongs_to :reviewable, polymorphic: true
  belongs_to :order, optional: true

  validates :rating, presence: true, inclusion: { in: 1..5 }
  validates :content, presence: true, length: { minimum: 10, maximum: 1000 }
  validates :review_type, presence: true, inclusion: { in: %w[order product website skillmaster] }
  validate :user_has_purchased, if: -> { review_type != 'website' }
  validate :one_review_per_order, if: -> { review_type == 'order' }

  private

  def user_has_purchased
    return if user.orders.completed.exists?

    errors.add(:base, 'You must have completed orders to leave a review')
  end

  def one_review_per_order
    return unless order_id && Review.exists?(order_id: order_id, review_type: 'order')

    errors.add(:order_id, 'has already been reviewed')
  end
end
