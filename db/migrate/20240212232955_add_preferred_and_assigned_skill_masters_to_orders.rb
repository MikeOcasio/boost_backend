class AddPreferredAndAssignedSkillMastersToOrders < ActiveRecord::Migration[6.0]
  def change
    add_reference :users, :preferred_skill_master, foreign_key: { to_table: :users }
    add_reference :orders, :assigned_skill_master, foreign_key: { to_table: :users }
  end
end
