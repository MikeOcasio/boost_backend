class OrderProduct < ApplicationRecord
  belongs_to :order
  belongs_to :product

    def price
      product.price
    end

    def tax
      product.tax
    end
end
