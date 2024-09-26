class RemoveOrderIdAndCartIdFromProducts < ActiveRecord::Migration[7.0]
  def change
    remove_column :products, :order_id, :bigint
    remove_column :products, :cart_id, :bigint
  end
end
