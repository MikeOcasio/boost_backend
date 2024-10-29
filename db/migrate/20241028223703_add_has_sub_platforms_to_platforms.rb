class AddHasSubPlatformsToPlatforms < ActiveRecord::Migration[7.0]
  def change
    add_column :platforms, :has_sub_platforms, :boolean, default: false
  end
end
