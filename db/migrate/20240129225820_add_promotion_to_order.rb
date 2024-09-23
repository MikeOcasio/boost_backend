class AddPromotionToOrder < ActiveRecord::Migration[6.0]
  def change
    add_reference :orders, :promotion, foreign_key: true
  end
end
