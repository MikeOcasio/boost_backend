class AddCustomAttributesToProducts < ActiveRecord::Migration[7.0]
  def change
    add_column :products, :is_active, :boolean
    add_column :products, :most_popular, :boolean
    add_column :products, :tag_line, :string
    add_column :products, :bg_image, :string
    add_column :products, :primary_color, :string
    add_column :products, :secondary_color, :string
    add_column :products, :features, :string, array: true, default: []
  end
end
