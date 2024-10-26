class AddAssociationsToProducts < ActiveRecord::Migration[6.0]
  def change
    add_reference :products, :category, foreign_key: true unless column_exists?(:products, :category_id)

    add_reference :products, :order, foreign_key: true unless column_exists?(:products, :order_id)

    return if column_exists?(:products, :cart_id)

    add_reference :products, :cart, foreign_key: true
  end
end
