class CreateProductPlatforms < ActiveRecord::Migration[7.0]
  def change
    create_table :product_platforms do |t|
      t.references :product, null: false, foreign_key: true
      t.references :platform, null: false, foreign_key: true

      t.timestamps
    end
  end
end
