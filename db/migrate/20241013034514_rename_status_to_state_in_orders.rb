class RenameStatusToStateInOrders < ActiveRecord::Migration[7.0]
  def change
    rename_column :orders, :status, :state
  end
end
