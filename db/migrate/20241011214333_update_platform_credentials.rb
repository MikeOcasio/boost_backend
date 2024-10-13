class UpdatePlatformCredentials < ActiveRecord::Migration[7.0]
  def change
    remove_column :platform_credentials, :encrypted_username, :string
    remove_column :platform_credentials, :encrypted_password, :string
    remove_column :platform_credentials, :encrypted_username_iv, :string
    remove_column :platform_credentials, :encrypted_password_iv, :string

    add_column :platform_credentials, :username, :string, limit: 1024
    add_column :platform_credentials, :password, :string, limit: 1024
  end
end
