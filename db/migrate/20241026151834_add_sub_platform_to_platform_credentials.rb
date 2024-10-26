# db/migrate/20241026120100_add_sub_platform_to_platform_credentials.rb
class AddSubPlatformToPlatformCredentials < ActiveRecord::Migration[7.0]
  def change
    add_reference :platform_credentials, :sub_platform, foreign_key: true
  end
end
