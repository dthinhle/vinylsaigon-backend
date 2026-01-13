class CreateCartItems < ActiveRecord::Migration[8.0]
  def change
    create_table :cart_items, id: :uuid do |t|
      t.uuid :cart_id, null: false
      t.bigint :product_id, null: false
      t.bigint :product_variant_id, null: true
      t.integer :quantity, null: false, default: 1

      t.decimal :current_price, precision: 10, scale: 2, null: false
      t.decimal :original_price, precision: 10, scale: 2, null: false
      t.string :currency, default: 'USD', null: false

      t.string :product_name, null: false
      t.string :product_image_url, null: true

      t.timestamps
      t.datetime :added_at, null: false
      t.datetime :expires_at, null: false
    end

    add_index :cart_items, :cart_id
    add_index :cart_items, :product_id
    add_index :cart_items, :product_variant_id
    add_index :cart_items, :expires_at
    add_index :cart_items, [:cart_id, :product_id, :product_variant_id], unique: true, name: 'index_cart_items_uniqueness'

    add_foreign_key :cart_items, :carts, column: :cart_id
    add_foreign_key :cart_items, :products, column: :product_id
    add_foreign_key :cart_items, :product_variants, column: :product_variant_id
  end
end
