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

  # Method to check if the product has a 'Levels' attribute category and apply dynamic pricing
  def calculate_price(start_level, end_level)
    # Check if the product has a Product Attribute Category for 'Levels'
    if prod_attr_cats.exists?(name: 'Levels')
      # Fetch the relevant level price for the product's category and selected levels
      level_prices = category.level_prices.where('min_level <= ? AND max_level >= ?', end_level, start_level)

      total_price = 0

      # Iterate over the range of levels to calculate total price
      (start_level..end_level).each do |level|
        level_price = level_prices.find { |lp| lp.min_level <= level && lp.max_level >= level }

        # If we find a matching level price range, add the price for this level
        if level_price
          total_price += level * level_price.price_per_level
        else
          # Handle case where no price is found for the level
          # You might want to raise an error, log it, or just continue
          Rails.logger.warn("No price found for level #{level} in product #{id}")
        end
      end

      return total_price.round(2) # Return the rounded total price
    end

    # Return a default price (0 or static price) if no level-based pricing applies
    0
  end

  private

  def has_at_least_one_platform
    errors.add(:platforms, 'must have at least one platform') if platforms.empty?
  end
end
