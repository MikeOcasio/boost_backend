class ChangePlatformToIntegerInOrders < ActiveRecord::Migration[6.0]
  def change
    change_column :orders, :platform, 'integer USING CAST(platform AS integer)'
  end
end
