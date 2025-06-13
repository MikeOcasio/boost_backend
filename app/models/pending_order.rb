class PendingOrder < ApplicationRecord
  belongs_to :user

  validates :paypal_order_id, presence: true, uniqueness: true
  validates :user_id, presence: true
  validates :total_price, presence: true, numericality: { greater_than: 0 }

  # Auto-cleanup old pending orders (older than 1 hour)
  scope :expired, -> { where('created_at < ?', 1.hour.ago) }

  def products_data
    JSON.parse(products || '[]')
  end

  def promo_data_hash
    return {} if promo_data.blank?
    JSON.parse(promo_data)
  end

  def order_data_hash
    return {} if order_data.blank?
    JSON.parse(order_data)
  end

  # Clean up expired pending orders
  def self.cleanup_expired
    expired.destroy_all
  end
end
