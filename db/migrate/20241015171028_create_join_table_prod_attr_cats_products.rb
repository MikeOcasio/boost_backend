class CreateJoinTableProdAttrCatsProducts < ActiveRecord::Migration[7.0]
  def change
    create_join_table :prod_attr_cats, :products do |t|
      t.index :prod_attr_cat_id, name: 'index_prod_attr_cats_on_pac_id'
      t.index :product_id, name: 'index_prod_attr_cats_on_product_id'
    end
  end
end

