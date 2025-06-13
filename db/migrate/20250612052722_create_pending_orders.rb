class CreatePendingOrders < ActiveRecord::Migration[7.0]
  def change
    create_table :pending_orders do |t|
      t.string :paypal_order_id
      t.integer :user_id
      t.integer :platform_id
      t.decimal :total_price
      t.text :products
      t.text :promo_data
      t.text :order_data

      t.timestamps
    end
  end
end
