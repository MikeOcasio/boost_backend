class AddAvailablePointsToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :available_completion_points, :integer, default: 0
    add_column :users, :available_referral_points, :integer, default: 0
    add_column :users, :total_completion_points, :integer, default: 0
    add_column :users, :total_referral_points, :integer, default: 0
  end
end
