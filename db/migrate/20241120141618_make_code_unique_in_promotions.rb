class MakeCodeUniqueInPromotions < ActiveRecord::Migration[7.0]
  def change
    add_index :promotions, :code, unique: true
  end
end
