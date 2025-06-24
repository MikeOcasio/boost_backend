class AddTitleToRewardPayouts < ActiveRecord::Migration[7.0]
  def change
    add_column :reward_payouts, :title, :string
  end
end
