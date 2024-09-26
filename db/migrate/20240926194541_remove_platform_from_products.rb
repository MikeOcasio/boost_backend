class RemovePlatformFromProducts < ActiveRecord::Migration[7.0]
  def change
    remove_column :products, :platform, :string
  end
end
