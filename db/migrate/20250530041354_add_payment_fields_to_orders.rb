class AddPaymentFieldsToOrders < ActiveRecord::Migration[7.0]
  def change
    add_column :orders, :stripe_session_id, :string
    add_column :orders, :stripe_payment_intent_id, :string
    add_column :orders, :payment_status, :string
    add_column :orders, :payment_captured_at, :datetime
    add_column :orders, :skillmaster_earned, :decimal, precision: 10, scale: 2
    add_column :orders, :company_earned, :decimal, precision: 10, scale: 2

    add_index :orders, :stripe_session_id
    add_index :orders, :stripe_payment_intent_id
    # Don't add assigned_skill_master_id index as it already exists
  end
end
