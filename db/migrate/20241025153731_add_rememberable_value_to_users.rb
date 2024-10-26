class AddRememberableValueToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :rememberable_value, :string
  end
end
