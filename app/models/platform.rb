class Platform < ApplicationRecord
  has_many :user_platforms, dependent: :destroy
  has_many :users, through: :user_platforms

  has_many :product_platforms, dependent: :destroy
  has_many :products, through: :product_platforms

  validates :name, presence: true, uniqueness: true
end
