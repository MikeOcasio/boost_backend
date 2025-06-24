# Add PayPal email field for customers to receive referral rewards
class AddCustomerPaypalEmailToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :cust_paypal_email, :string
    add_column :users, :cust_paypal_email_verified, :boolean, default: false
    add_column :users, :cust_paypal_email_verified_at, :datetime

    add_index :users, :cust_paypal_email
    add_index :users, :cust_paypal_email_verified
  end
end
