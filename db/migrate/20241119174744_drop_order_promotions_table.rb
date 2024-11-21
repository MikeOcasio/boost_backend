class DropOrderPromotionsTable < ActiveRecord::Migration[7.0]
  def change
    drop_table :order_promotions do |t|
      t.references :order, null: false, foreign_key: true
      t.references :promotion, null: false, foreign_key: true
      t.datetime :applied_at
      t.decimal :discount_amount
      t.timestamps
    end
  end
end
