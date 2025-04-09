# Create contractors table
class CreateContractors < ActiveRecord::Migration[7.0]
  def change
    create_table :contractors do |t|
      t.references :user, null: false, foreign_key: true
      t.string :stripe_account_id
      t.integer :available_balance, default: 0
      t.integer :pending_balance, default: 0
      t.datetime :last_synced_at
      t.timestamps
    end

    add_index :contractors, :stripe_account_id, unique: true
  end
end
