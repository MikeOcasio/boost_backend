class DropProductPromotionsTable < ActiveRecord::Migration[7.0]
  def change
    drop_table :product_promotions do |t|
      t.references :product, null: false, foreign_key: true
      t.references :promotion, null: false, foreign_key: true
      t.timestamps
    end
  end
end
