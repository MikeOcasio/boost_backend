# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.0].define(version: 2025_06_04_191610) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "app_statuses", force: :cascade do |t|
    t.string "status", default: "active", null: false
    t.string "message", default: "Application is running normally", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "banned_emails", force: :cascade do |t|
    t.string "email", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["email"], name: "index_banned_emails_on_email", unique: true
    t.index ["user_id"], name: "index_banned_emails_on_user_id"
  end

  create_table "bug_reports", force: :cascade do |t|
    t.string "title"
    t.text "description"
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_bug_reports_on_user_id"
  end

  create_table "carts", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "product_id", null: false
    t.integer "quantity"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id"], name: "index_carts_on_product_id"
    t.index ["user_id"], name: "index_carts_on_user_id"
  end

  create_table "categories", force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "is_active", default: true, null: false
    t.string "image"
    t.string "bg_image"
  end

  create_table "categories_skillmaster_apps", id: false, force: :cascade do |t|
    t.bigint "category_id", null: false
    t.bigint "skillmaster_application_id", null: false
    t.index ["category_id", "skillmaster_application_id"], name: "index_cat_sma_on_cat_id_and_sma_id", unique: true
  end

  create_table "chat_participants", force: :cascade do |t|
    t.bigint "chat_id", null: false
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["chat_id", "user_id"], name: "index_chat_participants_on_chat_id_and_user_id", unique: true
    t.index ["chat_id"], name: "index_chat_participants_on_chat_id"
    t.index ["user_id"], name: "index_chat_participants_on_user_id"
  end

  create_table "chats", force: :cascade do |t|
    t.bigint "initiator_id", null: false
    t.bigint "recipient_id", null: false
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "broadcast"
    t.string "title"
    t.string "chat_type", null: false
    t.string "ticket_number"
    t.string "status", default: "active"
    t.bigint "order_id"
    t.string "reference_id"
    t.integer "reopen_count", default: 0, null: false
    t.datetime "closed_at"
    t.datetime "reopened_at"
    t.index ["initiator_id", "recipient_id"], name: "index_chats_on_initiator_id_and_recipient_id", unique: true
    t.index ["initiator_id"], name: "index_chats_on_initiator_id"
    t.index ["order_id"], name: "index_chats_on_order_id"
    t.index ["recipient_id"], name: "index_chats_on_recipient_id"
    t.index ["reference_id"], name: "index_chats_on_reference_id", unique: true
    t.index ["ticket_number"], name: "index_chats_on_ticket_number", unique: true
  end

  create_table "contractors", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.datetime "last_payout_requested_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "stripe_account_id"
    t.decimal "available_balance", precision: 10, scale: 2, default: "0.0"
    t.decimal "pending_balance", precision: 10, scale: 2, default: "0.0"
    t.decimal "total_earned", precision: 10, scale: 2, default: "0.0"
    t.datetime "last_withdrawal_at"
    t.index ["user_id"], name: "index_contractors_on_user_id"
  end

  create_table "graveyards", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "jwt_denylist", force: :cascade do |t|
    t.string "jti", null: false
    t.datetime "exp", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["jti"], name: "index_jwt_denylist_on_jti"
  end

  create_table "messages", force: :cascade do |t|
    t.bigint "chat_id", null: false
    t.bigint "sender_id", null: false
    t.text "content"
    t.boolean "read", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["chat_id"], name: "index_messages_on_chat_id"
    t.index ["sender_id"], name: "index_messages_on_sender_id"
  end

  create_table "notifications", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.text "content"
    t.string "status"
    t.string "notification_type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_notifications_on_user_id"
  end

  create_table "order_products", force: :cascade do |t|
    t.bigint "order_id", null: false
    t.bigint "product_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["order_id"], name: "index_order_products_on_order_id"
    t.index ["product_id"], name: "index_order_products_on_product_id"
  end

  create_table "orders", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "state"
    t.decimal "total_price"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "promotion_id"
    t.bigint "assigned_skill_master_id"
    t.string "internal_id"
    t.decimal "price"
    t.decimal "tax"
    t.integer "platform"
    t.integer "platform_credential_id"
    t.integer "selected_level"
    t.decimal "dynamic_price", precision: 8, scale: 2
    t.string "promo_data"
    t.string "order_data", default: [], array: true
    t.bigint "referral_user_id"
    t.integer "points", default: 0
    t.string "stripe_session_id"
    t.string "stripe_payment_intent_id"
    t.string "payment_status"
    t.datetime "payment_captured_at"
    t.decimal "skillmaster_earned", precision: 10, scale: 2
    t.decimal "company_earned", precision: 10, scale: 2
    t.datetime "customer_verified_at"
    t.datetime "admin_reviewed_at"
    t.integer "admin_reviewer_id"
    t.datetime "submitted_for_review_at"
    t.text "skillmaster_submission_notes"
    t.text "admin_approval_notes"
    t.text "admin_rejection_notes"
    t.index ["assigned_skill_master_id"], name: "index_orders_on_assigned_skill_master_id"
    t.index ["promotion_id"], name: "index_orders_on_promotion_id"
    t.index ["referral_user_id"], name: "index_orders_on_referral_user_id"
    t.index ["stripe_payment_intent_id"], name: "index_orders_on_stripe_payment_intent_id"
    t.index ["stripe_session_id"], name: "index_orders_on_stripe_session_id"
    t.index ["user_id"], name: "index_orders_on_user_id"
  end

  create_table "platform_credentials", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "username", limit: 1024
    t.string "password", limit: 1024
    t.bigint "platform_id"
    t.bigint "sub_platform_id"
    t.index ["platform_id"], name: "index_platform_credentials_on_platform_id"
    t.index ["sub_platform_id"], name: "index_platform_credentials_on_sub_platform_id"
    t.index ["user_id"], name: "index_platform_credentials_on_user_id"
  end

  create_table "platforms", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "has_sub_platforms", default: false
  end

  create_table "platforms_skillmaster_apps", id: false, force: :cascade do |t|
    t.bigint "platform_id", null: false
    t.bigint "skillmaster_application_id", null: false
    t.index ["platform_id", "skillmaster_application_id"], name: "index_plat_sma_on_plat_id_and_sma_id", unique: true
  end

  create_table "preferred_skill_masters", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "preferred_skill_master_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["preferred_skill_master_id"], name: "index_preferred_skill_masters_on_preferred_skill_master_id"
    t.index ["user_id"], name: "index_preferred_skill_masters_on_user_id"
  end

  create_table "prod_attr_cats", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "prod_attr_cats_products", id: false, force: :cascade do |t|
    t.bigint "prod_attr_cat_id", null: false
    t.bigint "product_id", null: false
    t.index ["prod_attr_cat_id"], name: "index_prod_attr_cats_on_pac_id"
    t.index ["product_id"], name: "index_prod_attr_cats_on_product_id"
  end

  create_table "product_attribute_categories", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "product_categories", force: :cascade do |t|
    t.bigint "product_id", null: false
    t.bigint "category_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_product_categories_on_category_id"
    t.index ["product_id"], name: "index_product_categories_on_product_id"
  end

  create_table "product_platforms", force: :cascade do |t|
    t.bigint "product_id", null: false
    t.bigint "platform_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["platform_id"], name: "index_product_platforms_on_platform_id"
    t.index ["product_id"], name: "index_product_platforms_on_product_id"
  end

  create_table "products", force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.decimal "price"
    t.string "image"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "is_priority", default: false
    t.decimal "tax"
    t.boolean "is_active"
    t.boolean "most_popular"
    t.string "tag_line"
    t.string "bg_image"
    t.string "primary_color"
    t.string "secondary_color"
    t.string "features", default: [], array: true
    t.bigint "category_id"
    t.boolean "is_dropdown", default: false
    t.jsonb "dropdown_options", default: []
    t.boolean "is_slider", default: false
    t.jsonb "slider_range", default: []
    t.bigint "parent_id"
    t.index ["parent_id"], name: "index_products_on_parent_id"
  end

  create_table "promotions", force: :cascade do |t|
    t.string "code"
    t.decimal "discount_percentage"
    t.datetime "start_date", precision: nil
    t.datetime "end_date", precision: nil
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_promotions_on_code", unique: true
  end

  create_table "reviews", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "reviewable_type", null: false
    t.bigint "reviewable_id", null: false
    t.bigint "order_id"
    t.integer "rating", null: false
    t.text "content", null: false
    t.string "review_type", null: false
    t.boolean "verified_purchase", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["order_id"], name: "index_reviews_on_order_id"
    t.index ["reviewable_type", "reviewable_id"], name: "index_reviews_on_reviewable"
    t.index ["user_id", "reviewable_type", "reviewable_id"], name: "index_unique_order_reviews", unique: true, where: "((review_type)::text = 'order'::text)"
    t.index ["user_id"], name: "index_reviews_on_user_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.string "session_id", null: false
    t.text "data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["session_id"], name: "index_sessions_on_session_id", unique: true
    t.index ["updated_at"], name: "index_sessions_on_updated_at"
  end

  create_table "skillmaster_applications", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.string "status", default: "pending", null: false
    t.datetime "submitted_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.datetime "reviewed_at"
    t.bigint "reviewer_id"
    t.string "gamer_tag"
    t.text "reasons"
    t.string "images", default: [], array: true
    t.string "channels", default: [], array: true
    t.string "platforms", default: [], array: true
    t.string "games", default: [], array: true
    t.index ["reviewer_id"], name: "index_skillmaster_applications_on_reviewer_id"
    t.index ["user_id"], name: "index_skillmaster_applications_on_user_id"
  end

  create_table "sub_platforms", force: :cascade do |t|
    t.string "name", null: false
    t.bigint "platform_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["platform_id"], name: "index_sub_platforms_on_platform_id"
  end

  create_table "user_platforms", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "platform_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["platform_id"], name: "index_user_platforms_on_platform_id"
    t.index ["user_id"], name: "index_user_platforms_on_user_id"
  end

  create_table "user_rewards", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.integer "points", default: 0, null: false
    t.string "reward_type", null: false
    t.string "status", default: "pending", null: false
    t.decimal "amount", precision: 10, scale: 2
    t.datetime "claimed_at"
    t.datetime "paid_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_user_rewards_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email"
    t.string "first_name"
    t.string "last_name"
    t.string "role"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "encrypted_data"
    t.text "encrypted_symmetric_key"
    t.integer "preferred_skill_master_ids", default: [], array: true
    t.string "encrypted_password"
    t.datetime "remember_created_at"
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.integer "sign_in_count"
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.integer "failed_attempts"
    t.string "unlock_token"
    t.datetime "locked_at"
    t.string "otp_secret"
    t.integer "consumed_timestep"
    t.boolean "otp_required_for_login"
    t.string "platforms", default: [], array: true
    t.string "image_url"
    t.boolean "locked_by_admin", default: false
    t.datetime "deleted_at"
    t.string "gamer_tag"
    t.text "bio"
    t.string "achievements", default: [], array: true
    t.string "gameplay_info", default: [], array: true
    t.string "rememberable_value"
    t.boolean "otp_setup_complete"
    t.string "two_factor_method", default: "email"
    t.integer "available_completion_points", default: 0
    t.integer "available_referral_points", default: 0
    t.integer "total_completion_points", default: 0
    t.integer "total_referral_points", default: 0
    t.string "stripe_customer_id"
    t.index ["deleted_at"], name: "index_users_on_deleted_at"
    t.index ["preferred_skill_master_ids"], name: "index_users_on_preferred_skill_master_ids"
    t.check_constraint "role::text = ANY (ARRAY['admin'::character varying, 'skillmaster'::character varying, 'customer'::character varying, 'skillcoach'::character varying, 'coach'::character varying, 'dev'::character varying, 'c_support'::character varying, 'manager'::character varying]::text[])", name: "check_valid_role"
  end

  create_table "users_categories", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "category_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_users_categories_on_category_id"
    t.index ["user_id"], name: "index_users_categories_on_user_id"
  end

  create_table "websites", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "banned_emails", "users"
  add_foreign_key "bug_reports", "users"
  add_foreign_key "carts", "products"
  add_foreign_key "carts", "users"
  add_foreign_key "chat_participants", "chats"
  add_foreign_key "chat_participants", "users"
  add_foreign_key "chats", "orders"
  add_foreign_key "chats", "users", column: "initiator_id"
  add_foreign_key "chats", "users", column: "recipient_id"
  add_foreign_key "contractors", "users"
  add_foreign_key "messages", "chats"
  add_foreign_key "messages", "users", column: "sender_id"
  add_foreign_key "notifications", "users"
  add_foreign_key "order_products", "orders"
  add_foreign_key "order_products", "products"
  add_foreign_key "orders", "platform_credentials"
  add_foreign_key "orders", "promotions"
  add_foreign_key "orders", "users"
  add_foreign_key "orders", "users", column: "assigned_skill_master_id"
  add_foreign_key "orders", "users", column: "referral_user_id"
  add_foreign_key "platform_credentials", "platforms"
  add_foreign_key "platform_credentials", "sub_platforms"
  add_foreign_key "platform_credentials", "users"
  add_foreign_key "preferred_skill_masters", "preferred_skill_masters"
  add_foreign_key "preferred_skill_masters", "users"
  add_foreign_key "product_categories", "categories"
  add_foreign_key "product_categories", "products"
  add_foreign_key "product_platforms", "platforms"
  add_foreign_key "product_platforms", "products"
  add_foreign_key "products", "products", column: "parent_id"
  add_foreign_key "reviews", "orders"
  add_foreign_key "reviews", "users"
  add_foreign_key "skillmaster_applications", "users"
  add_foreign_key "skillmaster_applications", "users", column: "reviewer_id"
  add_foreign_key "sub_platforms", "platforms"
  add_foreign_key "user_platforms", "platforms"
  add_foreign_key "user_platforms", "users"
  add_foreign_key "user_rewards", "users"
  add_foreign_key "users_categories", "categories"
  add_foreign_key "users_categories", "users"
end
