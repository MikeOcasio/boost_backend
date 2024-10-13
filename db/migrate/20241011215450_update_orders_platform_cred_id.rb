class UpdateOrdersPlatformCredId < ActiveRecord::Migration[7.0]
  def change
    add_column :orders, :platform_credential_id, :integer
    add_foreign_key :orders, :platform_credentials
  end
end
