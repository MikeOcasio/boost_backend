class DropLevelPricesTable < ActiveRecord::Migration[7.0]
  def change
    drop_table :level_prices
  end
end
