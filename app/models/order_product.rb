class OrderProduct < ApplicationRecord
  belongs_to :order
  belongs_to :product

  delegate :price, to: :product

  delegate :tax, to: :product
end
