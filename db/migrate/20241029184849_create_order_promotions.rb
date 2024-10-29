class CreateOrderPromotions < ActiveRecord::Migration[7.0]
  def change
    create_table :order_promotions do |t|
      t.references :order, null: false, foreign_key: true
      t.references :promotion, null: false, foreign_key: true
      t.datetime :applied_at
      t.decimal :discount_amount, precision: 10, scale: 2
      t.timestamps
    end

    # Ensure a promotion can only be applied once per order
    add_index :order_promotions, %i[order_id promotion_id], unique: true
  end
end
