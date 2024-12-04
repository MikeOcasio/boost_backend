class AddOrderDataToOrders < ActiveRecord::Migration[7.0]
  def change
    add_column :orders, :order_data, :string, array: true, default: []
  end
end
