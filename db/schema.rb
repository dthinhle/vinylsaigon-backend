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

ActiveRecord::Schema[8.1].define(version: 2026_01_02_035944) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  # Custom types defined in this database.
  # Note that some types may not work with other database engines. Be careful if changing database.
  create_enum "cart_status", ["active", "expired", "checked_out", "emailed", "abandoned", "merged"]
  create_enum "cart_type_enum", ["authenticated", "anonymous"]
  create_enum "order_shipping_method", ["ship_to_address", "pick_up_at_store"]
  create_enum "order_status", ["awaiting_payment", "paid", "canceled", "fulfilled", "refunded", "failed"]
  create_enum "recipient_type", ["authenticated", "anonymous"]

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "addresses", force: :cascade do |t|
    t.string "address", null: false
    t.bigint "addressable_id"
    t.string "addressable_type"
    t.string "city", null: false
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.string "district"
    t.boolean "is_head_address", default: false
    t.string "map_url"
    t.string "phone_numbers", default: [], array: true
    t.datetime "updated_at", null: false
    t.string "ward"
    t.index ["addressable_type", "addressable_id"], name: "index_addresses_on_addressable"
  end

  create_table "admins", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "name", default: "", null: false
    t.boolean "order_notify", default: false, null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.datetime "updated_at", null: false
    t.index ["deleted_at"], name: "index_admins_on_deleted_at"
    t.index ["email"], name: "index_admins_on_email", unique: true
    t.index ["reset_password_token"], name: "index_admins_on_reset_password_token", unique: true
  end

  create_table "blog_categories", force: :cascade do |t|
    t.integer "blogs_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.string "name", null: false
    t.string "slug", null: false
    t.bigint "source_wp_id"
    t.datetime "updated_at", null: false
    t.index ["deleted_at"], name: "index_blog_categories_on_deleted_at"
    t.index ["slug"], name: "index_blog_categories_on_slug", unique: true
    t.index ["source_wp_id"], name: "index_blog_categories_on_source_wp_id", unique: true
  end

  create_table "blog_products", force: :cascade do |t|
    t.bigint "blog_id", null: false
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.bigint "product_id", null: false
    t.datetime "updated_at", null: false
    t.index ["blog_id"], name: "index_blog_products_on_blog_id"
    t.index ["deleted_at"], name: "index_blog_products_on_deleted_at"
    t.index ["product_id"], name: "index_blog_products_on_product_id"
  end

  create_table "blogs", force: :cascade do |t|
    t.bigint "author_id", null: false
    t.bigint "category_id"
    t.jsonb "content", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.string "meta_description", limit: 500
    t.string "meta_title", limit: 255
    t.datetime "published_at"
    t.string "slug", null: false
    t.bigint "source_wp_id"
    t.string "status", default: "draft", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.integer "view_count", default: 0
    t.index ["author_id"], name: "index_blogs_on_author_id"
    t.index ["category_id"], name: "index_blogs_on_category_id"
    t.index ["deleted_at"], name: "index_blogs_on_deleted_at"
    t.index ["slug"], name: "index_blogs_on_slug", unique: true, where: "(deleted_at IS NULL)"
    t.index ["source_wp_id"], name: "index_blogs_on_source_wp_id", unique: true
  end

  create_table "brands", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.string "name", null: false
    t.string "slug"
    t.datetime "updated_at", null: false
    t.index ["deleted_at"], name: "index_brands_on_deleted_at"
    t.index ["name"], name: "index_brands_on_name", unique: true
    t.index ["slug"], name: "index_brands_on_slug", unique: true
  end

  create_table "brands_products", id: false, force: :cascade do |t|
    t.bigint "brand_id", null: false
    t.bigint "product_id", null: false
    t.index ["brand_id", "product_id"], name: "index_brands_products_on_brand_and_product_id"
    t.index ["product_id", "brand_id"], name: "index_brands_products_on_product_and_brand_id"
  end

  create_table "cart_items", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "added_at", null: false
    t.uuid "cart_id", null: false
    t.datetime "created_at", null: false
    t.string "currency", default: "USD", null: false
    t.decimal "current_price", precision: 10, scale: 2, null: false
    t.datetime "expires_at", null: false
    t.decimal "original_price", precision: 10, scale: 2, null: false
    t.bigint "product_id", null: false
    t.string "product_image_url"
    t.string "product_name", null: false
    t.bigint "product_variant_id"
    t.integer "quantity", default: 1, null: false
    t.datetime "updated_at", null: false
    t.index ["cart_id", "product_id", "product_variant_id"], name: "index_cart_items_uniqueness", unique: true
    t.index ["cart_id"], name: "index_cart_items_on_cart_id"
    t.index ["expires_at"], name: "index_cart_items_on_expires_at"
    t.index ["product_id"], name: "index_cart_items_on_product_id"
    t.index ["product_variant_id"], name: "index_cart_items_on_product_variant_id"
  end

  create_table "cart_promotions", force: :cascade do |t|
    t.uuid "cart_id", null: false
    t.datetime "created_at", null: false
    t.bigint "promotion_id", null: false
    t.datetime "updated_at", null: false
    t.index ["cart_id"], name: "index_cart_promotions_on_cart_id"
    t.index ["promotion_id"], name: "index_cart_promotions_on_promotion_id"
  end

  create_table "carts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.enum "cart_type", default: "anonymous", enum_type: "cart_type_enum"
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "guest_email"
    t.datetime "last_activity_at", null: false
    t.jsonb "metadata", default: {}
    t.string "session_id", null: false
    t.enum "status", default: "active", enum_type: "cart_status"
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["expires_at"], name: "index_carts_on_expires_at"
    t.index ["guest_email"], name: "index_carts_on_guest_email"
    t.index ["last_activity_at"], name: "index_carts_on_last_activity_at"
    t.index ["session_id"], name: "index_carts_on_session_id"
    t.index ["status", "cart_type"], name: "index_carts_on_status_and_cart_type"
    t.index ["user_id"], name: "index_carts_on_user_id", where: "(user_id IS NOT NULL)"
  end

  create_table "categories", force: :cascade do |t|
    t.string "button_text"
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.string "description"
    t.boolean "is_root", default: false
    t.bigint "parent_id"
    t.string "slug"
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["deleted_at"], name: "index_categories_on_deleted_at"
    t.index ["parent_id"], name: "index_categories_on_parent_id"
    t.index ["title"], name: "index_categories_on_title"
  end

  create_table "emailed_carts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "access_token", null: false
    t.datetime "accessed_at"
    t.uuid "cart_id", null: false
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.datetime "expires_at", null: false
    t.enum "recipient_type", default: "anonymous", enum_type: "recipient_type"
    t.datetime "sent_at", null: false
    t.datetime "updated_at", null: false
    t.index ["access_token"], name: "index_emailed_carts_on_access_token", unique: true
    t.index ["cart_id"], name: "index_emailed_carts_on_cart_id"
    t.index ["email"], name: "index_emailed_carts_on_email"
    t.index ["expires_at"], name: "index_emailed_carts_on_expires_at"
  end

  create_table "hero_banners", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.text "description"
    t.string "main_title"
    t.string "text_color"
    t.datetime "updated_at", null: false
    t.string "url"
    t.index ["deleted_at"], name: "index_hero_banners_on_deleted_at"
  end

  create_table "menu_bar_items", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "image"
    t.string "item_type", null: false
    t.string "label", null: false
    t.string "link"
    t.bigint "menu_bar_section_id", null: false
    t.bigint "parent_id"
    t.integer "position", null: false
    t.datetime "updated_at", null: false
    t.index ["menu_bar_section_id"], name: "index_menu_bar_items_on_menu_bar_section_id"
    t.index ["parent_id"], name: "index_menu_bar_items_on_parent_id"
    t.index ["position"], name: "index_menu_bar_items_on_position"
  end

  create_table "menu_bar_sections", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "section_type", null: false
    t.datetime "updated_at", null: false
    t.index ["section_type"], name: "index_menu_bar_sections_on_section_type", unique: true
  end

  create_table "order_items", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "currency", default: "VND", null: false
    t.jsonb "metadata", default: {}
    t.uuid "order_id", null: false
    t.bigint "original_unit_price_vnd", null: false
    t.bigint "product_id"
    t.string "product_image_url"
    t.string "product_name", null: false
    t.bigint "product_variant_id"
    t.integer "quantity", default: 1, null: false
    t.bigint "subtotal_vnd", null: false
    t.bigint "unit_price_vnd", null: false
    t.datetime "updated_at", null: false
    t.datetime "warranty_expire_date"
    t.index ["order_id"], name: "index_order_items_on_order_id"
    t.index ["product_id"], name: "index_order_items_on_product_id"
  end

  create_table "orders", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.bigint "billing_address_id"
    t.uuid "cart_id"
    t.datetime "created_at", null: false
    t.string "currency", default: "VND", null: false
    t.bigint "discount_vnd", default: 0, null: false
    t.string "email"
    t.jsonb "metadata", default: {}
    t.string "name"
    t.string "order_number", null: false
    t.string "payment_method"
    t.string "payment_status", default: "pending", null: false
    t.string "phone_number"
    t.bigint "shipping_address_id"
    t.enum "shipping_method", default: "ship_to_address", null: false, enum_type: "order_shipping_method"
    t.bigint "shipping_vnd", default: 0, null: false
    t.enum "status", default: "awaiting_payment", null: false, enum_type: "order_status"
    t.bigint "store_address_id"
    t.bigint "subtotal_vnd", default: 0, null: false
    t.bigint "tax_vnd", default: 0, null: false
    t.bigint "total_vnd", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["cart_id"], name: "index_orders_on_cart_id"
    t.index ["email"], name: "index_orders_on_email"
    t.index ["order_number"], name: "index_orders_on_order_number", unique: true
    t.index ["payment_status"], name: "index_orders_on_payment_status"
    t.index ["status"], name: "index_orders_on_status"
    t.index ["user_id"], name: "index_orders_on_user_id"
  end

  create_table "payment_transactions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.decimal "amount"
    t.datetime "created_at", null: false
    t.string "merch_txn_ref"
    t.string "onepay_transaction_id"
    t.uuid "order_id", null: false
    t.jsonb "raw_callback"
    t.string "status"
    t.datetime "updated_at", null: false
    t.index ["merch_txn_ref"], name: "index_payment_transactions_on_merch_txn_ref"
    t.index ["onepay_transaction_id"], name: "index_payment_transactions_on_onepay_transaction_id", unique: true
    t.index ["order_id"], name: "index_payment_transactions_on_order_id"
  end

  create_table "product_bundles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "product_id", null: false
    t.bigint "product_variant_id"
    t.bigint "promotion_id", null: false
    t.integer "quantity", default: 1, null: false
    t.datetime "updated_at", null: false
    t.index ["product_id"], name: "index_product_bundles_on_product_id"
    t.index ["product_variant_id"], name: "index_product_bundles_on_product_variant_id"
    t.index ["promotion_id"], name: "index_product_bundles_on_promotion_id"
    t.check_constraint "quantity > 0", name: "chk_product_bundles_quantity_positive"
  end

  create_table "product_collections", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.string "description", limit: 80
    t.string "name", null: false
    t.string "slug"
    t.datetime "updated_at", null: false
    t.index ["deleted_at"], name: "index_product_collections_on_deleted_at"
    t.index ["name"], name: "index_product_collections_on_name", unique: true
    t.index ["slug"], name: "index_product_collections_on_slug", unique: true
  end

  create_table "product_collections_products", id: false, force: :cascade do |t|
    t.bigint "product_collection_id", null: false
    t.bigint "product_id", null: false
    t.index ["product_collection_id", "product_id"], name: "index_products_collections_on_collection_and_product_id"
    t.index ["product_id", "product_collection_id"], name: "index_products_collections_on_product_and_collection_id"
  end

  create_table "product_images", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "filename"
    t.integer "position", null: false
    t.bigint "product_variant_id", null: false
    t.datetime "updated_at", null: false
    t.index ["filename"], name: "index_product_images_on_filename"
    t.index ["product_variant_id"], name: "index_product_images_on_product_variant_id"
  end

  create_table "product_variants", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.decimal "current_price"
    t.datetime "deleted_at"
    t.string "name", null: false
    t.decimal "original_price"
    t.bigint "product_id", null: false
    t.string "short_description", limit: 80
    t.string "sku", null: false
    t.string "slug"
    t.integer "sort_order"
    t.string "status", default: "active", null: false
    t.integer "stock_quantity"
    t.datetime "updated_at", null: false
    t.jsonb "variant_attributes", default: {}
    t.index ["deleted_at"], name: "index_product_variants_on_deleted_at"
    t.index ["product_id", "sku"], name: "index_product_variants_on_product_id_and_sku", unique: true
    t.index ["product_id"], name: "index_product_variants_on_product_id"
  end

  create_table "products", force: :cascade do |t|
    t.bigint "category_id"
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.jsonb "description", default: {}, null: false
    t.boolean "featured", default: false, null: false
    t.string "flags", default: [], array: true
    t.boolean "free_installment_fee", default: true, null: false
    t.jsonb "gift_content", default: {}, null: false
    t.jsonb "legacy_attributes"
    t.integer "legacy_wp_id"
    t.integer "low_stock_threshold", default: 5, null: false
    t.string "meta_description", limit: 500
    t.string "meta_title", limit: 255
    t.string "name", null: false
    t.datetime "price_updated_at"
    t.jsonb "product_attributes", default: {}
    t.string "product_tags", default: [], array: true
    t.jsonb "short_description", default: {}, null: false
    t.string "sku", null: false
    t.string "slug"
    t.integer "sort_order", default: 0, null: false
    t.string "status", default: "active", null: false
    t.integer "stock_quantity", default: 0, null: false
    t.string "stock_status", default: "in_stock", null: false
    t.datetime "updated_at", null: false
    t.integer "warranty_months"
    t.decimal "weight", precision: 8, scale: 2
    t.index ["category_id"], name: "index_products_on_category_id"
    t.index ["deleted_at"], name: "index_products_on_deleted_at"
    t.index ["sku"], name: "index_products_on_sku", unique: true
    t.index ["slug"], name: "index_products_on_slug", unique: true
  end

  create_table "promotion_usages", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.jsonb "metadata", default: {}
    t.bigint "promotion_id", null: false
    t.uuid "redeemable_id"
    t.string "redeemable_type"
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["promotion_id", "created_at"], name: "index_promotion_usages_on_promotion_id_and_created_at"
    t.index ["promotion_id", "user_id"], name: "index_promotion_usages_on_promotion_id_and_user_id"
    t.index ["promotion_id"], name: "index_promotion_usages_on_promotion_id"
  end

  create_table "promotions", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.string "discount_type", null: false
    t.decimal "discount_value", precision: 10, scale: 2, null: false
    t.datetime "ends_at"
    t.bigint "max_discount_amount_vnd", default: 0, null: false
    t.jsonb "metadata"
    t.boolean "stackable", default: false, null: false
    t.datetime "starts_at"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.integer "usage_count", default: 0, null: false
    t.integer "usage_limit"
    t.index "lower((code)::text)", name: "index_promotions_on_lower_code", unique: true
    t.index ["active"], name: "index_promotions_on_active"
    t.index ["deleted_at"], name: "index_promotions_on_deleted_at"
    t.index ["ends_at"], name: "index_promotions_on_ends_at"
    t.index ["starts_at"], name: "index_promotions_on_starts_at"
    t.check_constraint "discount_value > 0::numeric", name: "chk_promotions_discount_value_positive"
    t.check_constraint "starts_at IS NULL OR ends_at IS NULL OR starts_at <= ends_at", name: "chk_promotions_starts_before_ends"
    t.check_constraint "usage_count >= 0", name: "chk_promotions_usage_count_non_negative"
    t.check_constraint "usage_limit IS NULL OR usage_limit >= 0", name: "chk_promotions_usage_limit_non_negative"
  end

  create_table "redirection_mappings", force: :cascade do |t|
    t.boolean "active", null: false
    t.datetime "created_at", null: false
    t.string "new_slug", null: false
    t.string "old_slug", null: false
    t.datetime "updated_at", null: false
    t.index ["old_slug", "active"], name: "index_redirection_mappings_on_old_slug_and_active"
    t.index ["old_slug"], name: "index_redirection_mappings_on_old_slug", unique: true
  end

  create_table "refresh_tokens", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "device_info"
    t.datetime "expires_at", null: false
    t.datetime "last_used_at"
    t.string "token", null: false
    t.string "token_ip"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["expires_at"], name: "index_refresh_tokens_on_expires_at"
    t.index ["token"], name: "index_refresh_tokens_on_token", unique: true
    t.index ["user_id"], name: "index_refresh_tokens_on_user_id"
  end

  create_table "related_categories", force: :cascade do |t|
    t.bigint "category_id", null: false
    t.datetime "created_at", null: false
    t.bigint "related_category_id", null: false
    t.datetime "updated_at", null: false
    t.integer "weight", null: false
    t.index ["category_id", "related_category_id"], name: "index_related_categories_unique", unique: true
    t.index ["category_id"], name: "index_related_categories_on_category_id"
    t.index ["related_category_id"], name: "index_related_categories_on_related_category_id"
  end

  create_table "related_products", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "product_id", null: false
    t.bigint "related_product_id", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id", "related_product_id"], name: "index_related_products_unique", unique: true
    t.index ["product_id"], name: "index_related_products_on_product_id"
    t.index ["related_product_id"], name: "index_related_products_on_related_product_id"
  end

  create_table "stores", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.string "facebook_url"
    t.string "instagram_url"
    t.string "name"
    t.datetime "updated_at", null: false
    t.string "youtube_url"
  end

  create_table "subscribers", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["email"], name: "index_subscribers_on_email", unique: true
    t.index ["user_id"], name: "index_subscribers_on_user_id"
  end

  create_table "system_configs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.string "value", null: false
    t.index ["name"], name: "index_system_configs_on_name", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.boolean "disabled", default: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "jti"
    t.string "name", default: "", null: false
    t.string "phone_number"
    t.string "refresh_token"
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.datetime "updated_at", null: false
    t.index ["deleted_at"], name: "index_users_on_deleted_at"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "versions", force: :cascade do |t|
    t.datetime "created_at"
    t.string "event", null: false
    t.bigint "item_id", null: false
    t.string "item_type", null: false
    t.text "object"
    t.text "object_changes"
    t.bigint "product_id"
    t.string "transaction_id"
    t.string "whodunnit"
    t.index ["item_type", "item_id"], name: "index_versions_on_item_type_and_item_id"
    t.index ["product_id"], name: "index_versions_on_product_id"
    t.index ["transaction_id"], name: "index_versions_on_transaction_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "blog_products", "blogs"
  add_foreign_key "blog_products", "products"
  add_foreign_key "blogs", "admins", column: "author_id"
  add_foreign_key "blogs", "blog_categories", column: "category_id"
  add_foreign_key "cart_items", "carts"
  add_foreign_key "cart_items", "product_variants"
  add_foreign_key "cart_items", "products"
  add_foreign_key "cart_promotions", "carts"
  add_foreign_key "cart_promotions", "promotions"
  add_foreign_key "carts", "users"
  add_foreign_key "categories", "categories", column: "parent_id"
  add_foreign_key "emailed_carts", "carts"
  add_foreign_key "menu_bar_items", "menu_bar_items", column: "parent_id"
  add_foreign_key "menu_bar_items", "menu_bar_sections"
  add_foreign_key "order_items", "orders"
  add_foreign_key "order_items", "product_variants"
  add_foreign_key "order_items", "products"
  add_foreign_key "orders", "addresses", column: "billing_address_id"
  add_foreign_key "orders", "addresses", column: "shipping_address_id"
  add_foreign_key "orders", "carts"
  add_foreign_key "orders", "users"
  add_foreign_key "payment_transactions", "orders"
  add_foreign_key "product_bundles", "product_variants"
  add_foreign_key "product_bundles", "products"
  add_foreign_key "product_bundles", "promotions"
  add_foreign_key "product_images", "product_variants"
  add_foreign_key "product_variants", "products"
  add_foreign_key "products", "categories"
  add_foreign_key "promotion_usages", "promotions", on_delete: :restrict
  add_foreign_key "refresh_tokens", "users"
  add_foreign_key "related_categories", "categories"
  add_foreign_key "related_categories", "categories", column: "related_category_id"
  add_foreign_key "related_products", "products"
  add_foreign_key "related_products", "products", column: "related_product_id"
  add_foreign_key "subscribers", "users"
end
