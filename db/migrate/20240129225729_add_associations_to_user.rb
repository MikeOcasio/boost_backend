class AddAssociationsToUser < ActiveRecord::Migration[6.0]
  def change
    unless column_exists?(:orders, :user_id)
      add_reference :orders, :user, foreign_key: true
    end

    unless column_exists?(:carts, :user_id)
      add_reference :carts, :user, foreign_key: true
    end

    unless column_exists?(:notifications, :user_id)
      add_reference :notifications, :user, foreign_key: true
    end
  end
end
