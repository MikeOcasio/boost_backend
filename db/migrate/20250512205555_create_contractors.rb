class CreateContractors < ActiveRecord::Migration[7.0]
  def change
    create_table :contractors do |t|
      t.references :user, null: false, foreign_key: true
      t.datetime :last_payout_requested_at

      t.timestamps
    end
  end
end
