class AddNewRolesToUsers < ActiveRecord::Migration[7.0]
  def up
    # Add check constraint for new roles
    execute <<-SQL
      ALTER TABLE users
      DROP CONSTRAINT IF EXISTS check_valid_role;

      ALTER TABLE users
      ADD CONSTRAINT check_valid_role
      CHECK (role IN ('admin', 'skillmaster', 'customer', 'skillcoach', 'coach', 'dev', 'c_support', 'manager'));
    SQL
  end

  def down
    execute <<-SQL
      ALTER TABLE users
      DROP CONSTRAINT IF EXISTS check_valid_role;

      ALTER TABLE users
      ADD CONSTRAINT check_valid_role
      CHECK (role IN ('admin', 'skillmaster', 'customer', 'skillcoach', 'coach', 'dev'));
    SQL
  end
end
