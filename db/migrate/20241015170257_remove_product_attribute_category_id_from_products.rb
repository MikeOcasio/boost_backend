class RemoveProductAttributeCategoryIdFromProducts < ActiveRecord::Migration[7.0]
  def change
    remove_column :products, :product_attribute_category_id, :integer
  end
end
