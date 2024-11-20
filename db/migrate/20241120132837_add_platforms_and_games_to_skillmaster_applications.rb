class AddPlatformsAndGamesToSkillmasterApplications < ActiveRecord::Migration[7.0]
  def change
    add_column :skillmaster_applications, :platforms, :string, array: true, default: []
    add_column :skillmaster_applications, :games, :string, array: true, default: []
  end
end
