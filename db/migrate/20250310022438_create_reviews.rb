class CreateReviews < ActiveRecord::Migration[7.0]
  def change
    create_table :reviews do |t|
      t.references :user, null: false, foreign_key: true
      t.references :reviewable, polymorphic: true, null: false
      t.references :order, foreign_key: true
      t.integer :rating, null: false
      t.text :content, null: false
      t.string :review_type, null: false
      t.boolean :verified_purchase, default: false
      t.timestamps
    end

    add_index :reviews, [:user_id, :reviewable_type, :reviewable_id], unique: true,
              where: "review_type = 'order'", name: 'index_unique_order_reviews'
  end
end
