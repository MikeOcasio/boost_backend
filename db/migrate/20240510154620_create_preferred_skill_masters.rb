class CreatePreferredSkillMasters < ActiveRecord::Migration[7.0]
  def change
    create_table :preferred_skill_masters do |t|
      t.references :user, null: false, foreign_key: true
      t.references :preferred_skill_master, null: false, foreign_key: true

      t.timestamps
    end
  end
end
