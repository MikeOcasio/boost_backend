class AddImagesToCategories < ActiveRecord::Migration[7.0]
  def change
    add_column :categories, :image, :string
    add_column :categories, :bg_image, :string
  end
end
