class CreateChatParticipants < ActiveRecord::Migration[7.0]
  def change
    create_table :chat_participants do |t|
      t.references :chat, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end

    add_index :chat_participants, [:chat_id, :user_id], unique: true
  end
end
