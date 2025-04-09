# Create payouts table to track history
class CreatePayouts < ActiveRecord::Migration[7.0]
  def change
    create_table :payouts do |t|
      t.references :contractor, null: false, foreign_key: true
      t.string :stripe_payout_id
      t.integer :amount
      t.string :currency, default: 'usd'
      t.string :status
      t.jsonb :metadata
      t.timestamps
    end

    add_index :payouts, :stripe_payout_id, unique: true
  end
end
