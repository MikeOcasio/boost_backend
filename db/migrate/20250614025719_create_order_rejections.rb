class CreateOrderRejections < ActiveRecord::Migration[7.0]
  def change
    create_table :order_rejections do |t|
      t.references :order, null: false, foreign_key: true
      t.references :admin_user, null: false, foreign_key: { to_table: :users }
      t.string :rejection_type, null: false # 'payment_rejection' or 'dispute_rejection'
      t.text :reason # Main rejection reason
      t.text :rejection_notes # Additional admin notes

      t.timestamps
    end

    add_index :order_rejections, [:order_id, :created_at]
    add_index :order_rejections, :rejection_type
  end
end
