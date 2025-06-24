# Create reward payout model
class CreateRewardPayouts < ActiveRecord::Migration[7.0]
  def change
    create_table :reward_payouts do |t|
      t.references :user_reward, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.string :status, default: 'pending', null: false
      t.string :payout_type, null: false # 'referral' or 'completion'
      t.string :paypal_payout_batch_id
      t.string :paypal_payout_item_id
      t.text :failure_reason
      t.json :paypal_response
      t.string :recipient_email
      t.datetime :processed_at

      t.timestamps
    end

    add_index :reward_payouts, :status
    add_index :reward_payouts, :payout_type
    add_index :reward_payouts, :paypal_payout_batch_id
  end
end
