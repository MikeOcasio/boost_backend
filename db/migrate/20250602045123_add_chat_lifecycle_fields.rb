class AddChatLifecycleFields < ActiveRecord::Migration[7.0]
  def change
    add_column :chats, :reference_id, :string
    add_column :chats, :reopen_count, :integer, default: 0, null: false
    add_column :chats, :closed_at, :datetime
    add_column :chats, :reopened_at, :datetime
    
    add_index :chats, :reference_id, unique: true
  end
end
