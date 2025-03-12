class CreateSkillmasterRewards < ActiveRecord::Migration[7.0]
  def change
    create_table :skillmaster_rewards do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :points, null: false, default: 0
      t.string :reward_type, null: false
      t.string :status, null: false, default: 'pending'
      t.decimal :amount, precision: 10, scale: 2
      t.datetime :claimed_at
      t.datetime :paid_at

      t.timestamps
    end
  end
end
