class Review < ApplicationRecord
  belongs_to :user
  belongs_to :reviewable, polymorphic: true
  belongs_to :order, optional: true

  validates :rating, presence: true, inclusion: { in: 1..5 }
  validates :content, presence: true, length: { minimum: 10, maximum: 1000 }
  validates :review_type, presence: true, inclusion: { in: %w[product order user website skillmaster] }
  validates :user_id, uniqueness: {
    scope: %i[reviewable_type reviewable_id],
    message: 'has already reviewed this item'
  }

  # Add validations for required associated IDs
  validates :reviewable_id, presence: true
  validates :order_id, presence: true, if: -> { review_type == 'order' }

  validate :validate_review_permissions
  # Custom validation to ensure proper associations
  validate :validate_required_associations

  private

  def validate_review_permissions
    case review_type
    when 'user'
      validate_user_review
    when 'order'
      validate_order_review
    when 'website'
      validate_website_review
    end
  end

  def validate_user_review
    return unless reviewable_type == 'User'

    if user.role == 'skillmaster'
      unless reviewable.role == 'customer' && completed_order_exists?
        errors.add(:base,
                   'Skillmasters can only review customers they have completed orders for')
      end
    elsif user.role == 'customer'
      unless reviewable.role == 'skillmaster' && completed_order_exists?
        errors.add(:base,
                   'Customers can only review skillmasters who have completed their orders')
      end
    else
      errors.add(:base, 'Invalid reviewer role')
    end
  end

  def validate_order_review
    return unless reviewable_type == 'Order'

    order = reviewable
    return if order.complete? && (user_id == order.user_id || user_id == order.assigned_skill_master_id)

    errors.add(:base, 'Can only review completed orders you were involved with')
  end

  def validate_website_review
    return unless review_type == 'website'

    return if Order.exists?(user_id: user_id, state: 'complete')

    errors.add(:base, 'Can only review the website after completing at least one order')
  end

  def completed_order_exists?
    Order.exists?(
      state: 'complete',
      user_id: [user_id, reviewable_id],
      assigned_skill_master_id: [user_id, reviewable_id]
    )
  end

  def validate_required_associations
    case review_type
    when 'product'
      errors.add(:reviewable_id, 'is required') if reviewable_id.blank?
      errors.add(:reviewable_type, "must be 'Product'") unless reviewable_type == 'Product'
    when 'skillmaster'
      errors.add(:reviewable_id, 'is required') if reviewable_id.blank?
      errors.add(:reviewable_type, "must be 'User'") unless reviewable_type == 'User'
    when 'order'
      errors.add(:order_id, 'is required') if order_id.blank?
      errors.add(:reviewable_id, 'is required') if reviewable_id.blank?
      errors.add(:reviewable_type, "must be 'Order'") unless reviewable_type == 'Order'
    when 'website'
      # No specific ID required for website reviews
    end
  end
end
