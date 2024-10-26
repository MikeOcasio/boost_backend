class AddPromotionToCart < ActiveRecord::Migration[6.0]
  def change
    return if table_exists?(:product_promotions)

    create_table :product_promotions do |t|
      t.references :product, foreign_key: true
      t.references :promotion, foreign_key: true
      t.timestamps
    end
  end
end
