class RemoveTrolleyFromContractors < ActiveRecord::Migration[7.0]
  def up
    # Remove Trolley-related fields from contractors table
    remove_index :contractors, :trolley_recipient_id if index_exists?(:contractors, :trolley_recipient_id)
    remove_column :contractors, :trolley_recipient_id, :string if column_exists?(:contractors, :trolley_recipient_id)
    remove_column :contractors, :trolley_account_status, :string if column_exists?(:contractors, :trolley_account_status)
  end

  def down
    # Add back Trolley fields if we need to rollback
    add_column :contractors, :trolley_recipient_id, :string
    add_column :contractors, :trolley_account_status, :string, default: 'pending'
    add_index :contractors, :trolley_recipient_id
  end
end
