class AddFieldsToSkillmasterApplication < ActiveRecord::Migration[7.0]
  def change
    add_reference :skillmaster_applications, :user, foreign_key: true, null: false
    add_column :skillmaster_applications, :status, :string, default: 'pending', null: false
    add_column :skillmaster_applications, :submitted_at, :datetime, null: false, default: -> { 'CURRENT_TIMESTAMP' }
    add_column :skillmaster_applications, :reviewed_at, :datetime
    add_reference :skillmaster_applications, :reviewer, foreign_key: { to_table: :users } # assuming reviewer is an admin or dev from users table
  end
end
