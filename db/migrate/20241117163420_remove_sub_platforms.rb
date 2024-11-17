class RemoveSubPlatforms < ActiveRecord::Migration[7.0]
  def up
    # Remove any foreign key references first
    remove_foreign_key :platform_credentials, :sub_platforms if foreign_key_exists?(:platform_credentials, :sub_platforms)

    # Remove any index on sub_platform_id in platform_credentials table
    remove_index :platform_credentials, :sub_platform_id if index_exists?(:platform_credentials, :sub_platform_id)

    # Now drop the sub_platforms table
    drop_table :sub_platforms do |t|
      t.string :name, null: false
      t.references :platform, null: false, foreign_key: true
      t.timestamps
    end
  end

  def down
    # Recreate the sub_platforms table if we ever want to rollback the migration
    create_table :sub_platforms do |t|
      t.string :name, null: false
      t.references :platform, null: false, foreign_key: true
      t.timestamps
    end

    # Add back the index and foreign key on platform_credentials
    add_index :platform_credentials, :sub_platform_id
    add_foreign_key :platform_credentials, :sub_platforms
  end
end
