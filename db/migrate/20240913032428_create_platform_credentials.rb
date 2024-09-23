class CreatePlatformCredentials < ActiveRecord::Migration[7.0]
  def change
    create_table :platform_credentials do |t|
      t.references :user, null: false, foreign_key: true
      t.string :encrypted_username
      t.string :encrypted_password
      t.string :encrypted_username_iv
      t.string :encrypted_password_iv

      t.timestamps
    end
  end
end
