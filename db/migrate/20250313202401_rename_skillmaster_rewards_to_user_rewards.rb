class RenameSkillmasterRewardsToUserRewards < ActiveRecord::Migration[7.0]
  def change
    rename_table :skillmaster_rewards, :user_rewards
    rename_column :orders, :referral_skillmaster_id, :referral_user_id
  end
end
