class AddTaxToProducts < ActiveRecord::Migration[7.0]
  def change
    add_column :products, :tax, :decimal
  end
end
