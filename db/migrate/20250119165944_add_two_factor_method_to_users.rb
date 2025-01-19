class AddTwoFactorMethodToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :two_factor_method, :string, default: 'email'

    # Ensure existing users with 2FA set up via the app retain their method
    reversible do |dir|
      dir.up do
        User.where(otp_required_for_login: true, otp_setup_complete: true).update_all(two_factor_method: 'app')
      end
    end
  end
end
