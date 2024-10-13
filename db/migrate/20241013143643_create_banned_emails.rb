class CreateBannedEmails < ActiveRecord::Migration[7.0]
  def change
    create_table :banned_emails do |t|
      t.string :email, null: false

      t.timestamps
    end
    add_index :banned_emails, :email, unique: true
  end
end
