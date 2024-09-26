class ProductPlatform < ApplicationRecord
  belongs_to :product
  belongs_to :platform
end
