class AddEncryptedDataToUsers < ActiveRecord::Migration[6.0]
  def change
    add_column :users, :encrypted_data, :text
    add_column :users, :encrypted_symmetric_key, :text
  end
end
