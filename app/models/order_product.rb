class OrderProduct < ApplicationRecord
  belongs_to :order
  belongs_to :product

  validates :quantity, presence: true, numericality: { greater_than: 0 }
  validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }

  delegate :tax, to: :product

  # Calculate total price for this line item
  def total_price
    (price + tax) * quantity
  end
end
