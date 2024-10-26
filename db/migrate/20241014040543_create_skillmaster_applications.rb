class CreateSkillmasterApplications < ActiveRecord::Migration[7.0]
  def change
    create_table :skillmaster_applications do |t|
      t.timestamps
    end
  end
end
