class AddSkillAttrToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :bio, :text                # Bio will be a text field for description
    add_column :users, :achievements, :string, array: true, default: []  # Array of strings for achievements
    add_column :users, :gameplay_info, :string, array: true, default: [] # Array of URLs for gameplay videos
  end
end

