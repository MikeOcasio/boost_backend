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

  has_many :order_products, dependent: :nullify
  has_many :orders, through: :order_products

  has_many :carts

  has_many :product_platforms, dependent: :destroy
  has_many :platforms, through: :product_platforms

  has_many :product_platforms, dependent: :nullify
  has_many :promotions, through: :product_promotions

  belongs_to :parent, class_name: 'Product', optional: true, inverse_of: :children
  has_many :children, class_name: 'Product', foreign_key: 'parent_id', dependent: :nullify, inverse_of: :parent

  validates :name, presence: true
  validates :price, presence: true

  validate :has_at_least_one_platform

  # Optional method to inherit attributes from the parent
  def inherit_attributes_from_parent
    return unless parent

    self.price ||= parent.price
    self.category_id ||= parent.category_id
    self.prod_attr_cat_id ||= parent.prod_attr_cat_id
    self.is_priority ||= parent.is_priority
    self.tax ||= parent.tax
    self.is_active ||= parent.is_active
    self.most_popular ||= parent.most_popular
    self.tag_line ||= parent.tag_line
    self.bg_image ||= parent.bg_image
    self.primary_color ||= parent.primary_color
    self.secondary_color ||= parent.secondary_color
    self.features ||= parent.features
  end

  # Scope to find products by platform
  scope :by_platform, ->(platform_id) { joins(:platforms).where(platforms: { id: platform_id }) }

  private

  def has_at_least_one_platform
    errors.add(:platforms, 'must have at least one platform') if platforms.empty?
  end
end
