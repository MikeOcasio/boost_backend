class CreateAppStatuses < ActiveRecord::Migration[7.0]
  def change
    create_table :app_statuses do |t|
      t.string :status, null: false, default: 'active'
      t.string :message, null: false, default: 'Application is running normally'
      t.timestamps
    end
  end
end
