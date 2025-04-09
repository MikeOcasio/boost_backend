class AddStrikesAndReviewModeration < ActiveRecord::Migration[7.0]
  def change
    # Add strikes to users
    add_column :users, :strikes, :integer, default: 0, null: false
    add_column :users, :banned_at, :datetime, null: true

    # Create review moderation table
    create_table :review_moderations do |t|
      t.references :review, null: false, foreign_key: { on_delete: :cascade }
      t.references :moderator, null: false, foreign_key: { to_table: :users }
      t.references :user, null: false, foreign_key: true
      t.text :reason, null: false
      t.boolean :strike_applied, default: true
      t.timestamps
    end

    # Add moderation status to reviews
    add_column :reviews, :moderated_at, :datetime
    add_column :reviews, :moderation_reason, :text
    add_column :reviews, :moderated_by_id, :bigint
    add_foreign_key :reviews, :users, column: :moderated_by_id
  end
end
