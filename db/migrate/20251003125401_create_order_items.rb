class CreateOrderItems < ActiveRecord::Migration[8.0]
  def change
    create_table :order_items, id: :uuid do |t|
      t.uuid :order_id, null: false
      t.bigint :product_id, null: true
      t.bigint :product_variant_id, null: true

      t.string :product_name, null: false
      t.string :product_image_url, null: true

      t.integer :quantity, null: false, default: 1

      t.bigint :unit_price_vnd, null: false
      t.bigint :original_unit_price_vnd, null: false
      t.bigint :subtotal_vnd, null: false
      t.string :currency, default: 'VND', null: false

      t.jsonb :metadata, default: {}

      t.timestamps
    end

    add_index :order_items, :order_id
    add_index :order_items, :product_id

    add_foreign_key :order_items, :orders, column: :order_id
    add_foreign_key :order_items, :products, column: :product_id
    add_foreign_key :order_items, :product_variants, column: :product_variant_id
  end
end
