class OrderProduct < ApplicationRecord
  belongs_to :order
  belongs_to :product

  validates :quantity, presence: true, numericality: { greater_than: 0 }

  delegate :price, to: :product
  delegate :tax, to: :product

  # Calculate total price for this line item
  def total_price
    (price + tax) * quantity
  end
end
