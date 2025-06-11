class MigrateStripeToPaypalAndTrolley < ActiveRecord::Migration[7.0]
  def up
    # Remove Stripe-specific columns
    remove_column :orders, :stripe_checkout_session_id, :string if column_exists?(:orders, :stripe_checkout_session_id)
    remove_column :orders, :stripe_payment_intent_id, :string if column_exists?(:orders, :stripe_payment_intent_id)
    remove_column :users, :stripe_customer_id, :string if column_exists?(:users, :stripe_customer_id)
    remove_column :contractors, :stripe_account_id, :string if column_exists?(:contractors, :stripe_account_id)

    # Add PayPal-specific columns to orders
    add_column :orders, :paypal_order_id, :string
    add_column :orders, :paypal_capture_id, :string
    add_column :orders, :paypal_payment_status, :string, default: 'pending'

    # Add PayPal customer information to users
    add_column :users, :paypal_customer_id, :string
    add_column :users, :paypal_email, :string

    # Add Trolley and PayPal information to contractors
    add_column :contractors, :trolley_recipient_id, :string
    add_column :contractors, :trolley_account_status, :string, default: 'pending'
    add_column :contractors, :paypal_payout_email, :string
    add_column :contractors, :tax_form_status, :string, default: 'pending' # 'pending', 'submitted', 'approved', 'rejected'
    add_column :contractors, :tax_form_type, :string # 'W-9' or 'W-8BEN'
    add_column :contractors, :tax_form_submitted_at, :timestamp
    add_column :contractors, :tax_compliance_checked_at, :timestamp

    # Create new table for tracking payment approvals
    create_table :payment_approvals do |t|
      t.references :order, null: false, foreign_key: true
      t.references :admin_user, null: false, foreign_key: { to_table: :users }
      t.string :status, default: 'pending' # 'pending', 'approved', 'rejected'
      t.text :notes
      t.timestamp :approved_at
      t.timestamp :rejected_at
      t.timestamps
    end

    # Create table for PayPal payout tracking
    create_table :paypal_payouts do |t|
      t.references :contractor, null: false, foreign_key: true
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.string :paypal_payout_batch_id
      t.string :paypal_payout_item_id
      t.string :status, default: 'pending' # 'pending', 'processing', 'success', 'failed'
      t.text :failure_reason
      t.json :paypal_response
      t.timestamps
    end

    # Add indexes for performance
    add_index :orders, :paypal_order_id
    add_index :orders, :paypal_capture_id
    add_index :users, :paypal_customer_id
    add_index :contractors, :trolley_recipient_id
    add_index :contractors, :paypal_payout_email
    add_index :payment_approvals, [:order_id, :status]
    add_index :paypal_payouts, [:contractor_id, :status]
  end

  def down
    # Remove PayPal and Trolley columns
    remove_column :orders, :paypal_order_id
    remove_column :orders, :paypal_capture_id
    remove_column :orders, :paypal_payment_status
    remove_column :users, :paypal_customer_id
    remove_column :users, :paypal_email
    remove_column :contractors, :trolley_recipient_id
    remove_column :contractors, :trolley_account_status
    remove_column :contractors, :paypal_payout_email
    remove_column :contractors, :tax_form_status
    remove_column :contractors, :tax_form_type
    remove_column :contractors, :tax_form_submitted_at
    remove_column :contractors, :tax_compliance_checked_at

    # Drop new tables
    drop_table :paypal_payouts
    drop_table :payment_approvals

    # Re-add Stripe columns (commented out as they may not be needed for rollback)
    # add_column :orders, :stripe_checkout_session_id, :string
    # add_column :orders, :stripe_payment_intent_id, :string
    # add_column :users, :stripe_customer_id, :string
    # add_column :contractors, :stripe_account_id, :string
  end
end
