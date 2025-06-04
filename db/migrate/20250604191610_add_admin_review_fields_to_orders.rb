class AddAdminReviewFieldsToOrders < ActiveRecord::Migration[7.0]
  def change
    add_column :orders, :submitted_for_review_at, :datetime
    # admin_reviewed_at and admin_reviewer_id already exist
    add_column :orders, :skillmaster_submission_notes, :text
    add_column :orders, :admin_approval_notes, :text
    add_column :orders, :admin_rejection_notes, :text
  end
end
