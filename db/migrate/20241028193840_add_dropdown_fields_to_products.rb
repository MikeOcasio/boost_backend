class AddDropdownFieldsToProducts < ActiveRecord::Migration[7.0]
  def change
    add_column :products, :is_dropdown, :boolean, default: false
    add_column :products, :dropdown_options, :jsonb, default: []
  end
end
