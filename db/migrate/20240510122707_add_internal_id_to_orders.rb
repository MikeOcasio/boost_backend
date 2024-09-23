class AddInternalIdToOrders < ActiveRecord::Migration[7.0]
  def change
    add_column :orders, :internal_id, :string
  end
end
