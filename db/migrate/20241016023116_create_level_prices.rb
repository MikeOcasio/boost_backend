class CreateLevelPrices < ActiveRecord::Migration[7.0]
  def change
    create_table :level_prices do |t|
      t.references :category, null: false, foreign_key: true
      t.integer :min_level, null: false
      t.integer :max_level, null: false
      t.decimal :price_per_level, precision: 8, scale: 2, null: false
      t.timestamps
    end
  end
end
