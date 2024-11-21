class AddChannelsToSkillmasterApplications < ActiveRecord::Migration[7.0]
  def change
    add_column :skillmaster_applications, :channels, :string, array: true, default: []
  end
end
