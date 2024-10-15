# Table name: products
#
#  id                          :bigint           not null, primary key
#  name                        :string
#  description                 :text
#  price                       :decimal
#  image                       :string
#  category_id                 :bigint
#  product_attribute_category_id :bigint
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  is_priority                 :boolean          default(false)
#  tax                         :decimal
#  is_active                   :boolean          default(false)
#  most_popular                :boolean          default(false)
#  tag_line                    :string
#  bg_image                    :string
#  primary_color               :string
#  secondary_color             :string
#  features                    :string           default([]), is an Array

class Product < ApplicationRecord
  belongs_to :category
  has_and_belongs_to_many :prod_attr_cats

  has_many :order_products
  has_many :orders, through: :order_products

  has_many :carts

  has_many :product_platforms, dependent: :destroy
  has_many :platforms, through: :product_platforms

  has_many :product_promotions
  has_many :promotions, through: :product_promotions

  validates :name, presence: true
  validates :price, presence: true

  validate :has_at_least_one_platform

  # Scope to find products by platform
  scope :by_platform, ->(platform_id) { joins(:platforms).where(platforms: { id: platform_id }) }

private

  def has_at_least_one_platform
    errors.add(:platforms, "must have at least one platform") if platforms.empty?
  end

end
