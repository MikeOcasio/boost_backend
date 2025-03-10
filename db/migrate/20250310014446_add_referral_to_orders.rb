class AddReferralToOrders < ActiveRecord::Migration[7.0]
  def change
    add_reference :orders, :referral_skillmaster, foreign_key: { to_table: :users }
    add_column :orders, :points, :integer, default: 0
  end
end
