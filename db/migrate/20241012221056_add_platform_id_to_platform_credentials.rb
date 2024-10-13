class AddPlatformIdToPlatformCredentials < ActiveRecord::Migration[7.0]
  def change
    add_reference :platform_credentials, :platform, foreign_key: true
  end
end
