class MakeAdminUserIdOptionalInPaymentApprovals < ActiveRecord::Migration[7.0]
  def change
    change_column_null :payment_approvals, :admin_user_id, true
  end
end
