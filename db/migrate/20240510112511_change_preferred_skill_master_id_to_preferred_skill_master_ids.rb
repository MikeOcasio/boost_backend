class ChangePreferredSkillMasterIdToPreferredSkillMasterIds < ActiveRecord::Migration[7.0]
  def up
    # remove the foreign key constraint
    remove_foreign_key :users, column: :preferred_skill_master_id

    # rename the column and change its type
    rename_column :users, :preferred_skill_master_id, :preferred_skill_master_ids
    change_column :users, :preferred_skill_master_ids, :integer, array: true, default: [], using: "(ARRAY[preferred_skill_master_ids]::INTEGER[])"
  end

  def down
    # revert the changes
    change_column :users, :preferred_skill_master_ids, :bigint, array: false, using: "(preferred_skill_master_ids[1])"
    rename_column :users, :preferred_skill_master_ids, :preferred_skill_master_id

    # add the foreign key constraint back
    add_foreign_key :users, :skill_masters, column: :preferred_skill_master_id
  end
end
