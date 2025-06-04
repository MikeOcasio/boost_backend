class AddVerificationFieldsToOrders < ActiveRecord::Migration[7.0]
  def change
    add_column :orders, :customer_verified_at, :datetime
    add_column :orders, :admin_reviewed_at, :datetime
    add_column :orders, :admin_reviewer_id, :integer
  end
end
