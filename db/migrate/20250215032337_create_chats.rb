class CreateChats < ActiveRecord::Migration[7.0]
  def change
    create_table :chats do |t|
      t.references :customer, null: false, foreign_key: { to_table: :users }
      t.references :booster, null: false, foreign_key: { to_table: :users }
      t.boolean :active, default: true

      t.timestamps
    end

    add_index :chats, [:customer_id, :booster_id], unique: true
  end
end
