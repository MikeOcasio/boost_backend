class AddPaypalVerificationToContractors < ActiveRecord::Migration[7.0]
  def change
    add_column :contractors, :paypal_email_verified, :boolean, default: false, null: false
    add_column :contractors, :paypal_email_verified_at, :datetime
    add_column :contractors, :paypal_verification_batch_id, :string
    add_column :contractors, :paypal_verification_attempts, :integer, default: 0, null: false
    add_column :contractors, :paypal_verification_last_attempt_at, :datetime

    add_index :contractors, :paypal_email_verified
    add_index :contractors, :paypal_verification_batch_id
  end
end
