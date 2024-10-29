class AddIsActiveToPromotions < ActiveRecord::Migration[7.0]
  def change
    add_column :promotions, :is_active, :boolean, default: false, null: false
  end
end
