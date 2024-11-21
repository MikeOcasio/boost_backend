class AddParentToProducts < ActiveRecord::Migration[7.0]
  def change
    add_reference :products, :parent, foreign_key: { to_table: :products }
  end
end
