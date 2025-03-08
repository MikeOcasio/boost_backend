class AddBroadcastToChats < ActiveRecord::Migration[7.0]
  def change
    add_column :chats, :broadcast, :boolean
    add_column :chats, :title, :string
  end
end
