class AddIsActiveToCategories < ActiveRecord::Migration[7.0]
  def change
    add_column :categories, :is_active, :boolean, default: true, null: false
  end
end
