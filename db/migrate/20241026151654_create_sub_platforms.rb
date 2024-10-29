# db/migrate/20241026120000_create_sub_platforms.rb
class CreateSubPlatforms < ActiveRecord::Migration[7.0]
  def change
    create_table :sub_platforms do |t|
      t.references :platform, null: false, foreign_key: true
      t.string :name, null: false

      t.timestamps
    end

    add_index :sub_platforms, %i[platform_id name], unique: true
  end
end
