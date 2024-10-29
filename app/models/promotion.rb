# == Schema Information
#
# Table name: promotions
#
#  id                 :bigint           not null, primary key
#  code               :string
#  discount_percentage: decimal
#  start_date         :datetime
#  end_date           :datetime
#  created_at         :datetime         not null
#  updated_at         :datetime         not null

class Promotion < ApplicationRecord
  has_many :order_promotions
  has_many :orders, through: :order_promotions

  # Ensure the promotion is active before allowing use
  def active?
    start_date <= Time.current && end_date >= Time.current
  end

  # Apply discount, given the order amount
  def calculate_discount(amount)
    amount * (discount_percentage / 100.0)
  end
end
