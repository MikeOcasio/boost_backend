class DropPlatformSkillmasterApps < ActiveRecord::Migration[7.0]
  def change
    drop_table :platform_skillmaster_apps do |t|
      t.references :platform, null: false, foreign_key: true
      t.references :skillmaster_application, null: false, foreign_key: true

      t.timestamps
    end
  end
end
