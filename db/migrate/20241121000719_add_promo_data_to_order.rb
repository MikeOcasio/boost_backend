class AddPromoDataToOrder < ActiveRecord::Migration[7.0]
  def change
    add_column :orders, :promo_data, :string
  end
end
