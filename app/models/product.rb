  # == Schema Information
  #
  # Table name: products
  #
  #  id          :bigint           not null, primary key
  #  name        :string
  #  description :text
  #  price       :decimal
  #  image       :string
  #  category_id :bigint
  #  created_at  :datetime         not null
  #  updated_at  :datetime         not null
  #  Features    :string           default([]), is an Array
  
  # Relationships
  # - belongs_to :category
  # - has_many :orders

class Product < ApplicationRecord
  belongs_to :category
  belongs_to :product_attribute_category

  has_many :order_products
  has_many :orders, through: :order_products

  has_many :carts

  has_many :product_promotions
  has_many :promotions, through: :product_promotions

  validates :platform, presence: true
  validates :name, presence: true
  validates :price, presence: true

  # Scope to find products by platform
  scope :by_platform, ->(platform) { where(platform: platform) }

  def to_s
    "#{name} - $#{'%.2f' % price}"
  end


  def inspect
    formatted_price = price ? '$' + format('%.2f', price) : 'N/A'
    priority_status = is_priority ? 'Priority' : 'Not Priority'
    "#<Product id: #{id}, name: #{name}, description: #{description}, price: #{formatted_price}, image: #{image}, category_id: #{category_id}, created_at: #{created_at}, updated_at: #{updated_at}, order_id: #{order_id}, cart_id: #{cart_id}, is_priority: #{priority_status}>"
  end

end
