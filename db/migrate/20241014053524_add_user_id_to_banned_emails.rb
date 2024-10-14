class AddUserIdToBannedEmails < ActiveRecord::Migration[7.0]
  def change
    add_reference :banned_emails, :user, null: false, foreign_key: true
  end
end
