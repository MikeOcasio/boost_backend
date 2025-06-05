class AddQuantityToOrderProducts < ActiveRecord::Migration[7.0]
  def change
    add_column :order_products, :quantity, :integer, default: 1, null: false
  end
end
