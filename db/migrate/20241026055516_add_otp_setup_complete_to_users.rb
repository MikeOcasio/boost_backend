class AddOtpSetupCompleteToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :otp_setup_complete, :boolean
  end
end
