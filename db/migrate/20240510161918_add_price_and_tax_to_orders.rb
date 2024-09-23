class AddPriceAndTaxToOrders < ActiveRecord::Migration[7.0]
  def change
    add_column :orders, :price, :decimal
    add_column :orders, :tax, :decimal
  end
end
