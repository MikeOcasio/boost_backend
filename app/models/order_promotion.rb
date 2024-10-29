class OrderPromotion < ApplicationRecord
  belongs_to :order
  belongs_to :promotion

  # Validation to ensure a promotion can only be applied once per order
  validates :order_id, uniqueness: { scope: :promotion_id }
end
