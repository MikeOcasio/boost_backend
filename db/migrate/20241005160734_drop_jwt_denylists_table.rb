class DropJwtDenylistsTable < ActiveRecord::Migration[7.0]
  def change
    drop_table :jwt_denylists
  end
end
