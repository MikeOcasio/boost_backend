class AddPlatformsToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :platforms, :string, array: true, default: []
  end
end
