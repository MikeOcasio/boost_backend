class AddPreferredPlatformsToUsers < ActiveRecord::Migration[7.0]
  def change
    def change
      add_column :users, :preferred_platforms, :jsonb, default: {}
    end
  end
end
