class DropCategorySkillmasterApps < ActiveRecord::Migration[7.0]
  def change
    drop_table :category_skillmaster_apps do |t|
      t.references :category, null: false, foreign_key: true
      t.references :skillmaster_application, null: false, foreign_key: true

      t.timestamps
    end
  end
end
