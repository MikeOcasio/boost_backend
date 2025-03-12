class UpdateChatsTable < ActiveRecord::Migration[7.0]
  def change
    rename_column :chats, :customer_id, :initiator_id
    rename_column :chats, :booster_id, :recipient_id

    add_column :chats, :chat_type, :string, null: false
    add_column :chats, :ticket_number, :string
    add_column :chats, :status, :string, default: 'active'
    add_reference :chats, :order, foreign_key: true

    # Only remove the index if it exists
    if index_exists?(:chats, [:customer_id, :booster_id])
      remove_index :chats, [:customer_id, :booster_id]
    end

    add_index :chats, :ticket_number, unique: true
  end
end
