class CreateProdAttrCats < ActiveRecord::Migration[7.0]
  def change
    create_table :prod_attr_cats do |t|
      t.string :name, null: false

      t.timestamps
    end
  end
end
