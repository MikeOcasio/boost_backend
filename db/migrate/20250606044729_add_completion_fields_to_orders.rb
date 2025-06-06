class AddCompletionFieldsToOrders < ActiveRecord::Migration[7.0]
  def change
    add_column :orders, :completion_data, :json
    add_column :orders, :before_image, :text
    add_column :orders, :after_image, :text
  end
end
