class RemoveIsActiveFromPromotions < ActiveRecord::Migration[7.0]
  def change
    remove_column :promotions, :is_active, :boolean
  end
end
