class AddLockedByAdminToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :locked_by_admin, :boolean, default: false
  end
end
