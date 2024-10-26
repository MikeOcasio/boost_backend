class AddSelectedLevelAndDynamicPriceToOrders < ActiveRecord::Migration[7.0]
  def change
    # Add selected_level column to store the level chosen by the user
    add_column :orders, :selected_level, :integer

    # Add dynamic_price column to store the price based on selected level
    add_column :orders, :dynamic_price, :decimal, precision: 8, scale: 2
  end
end
