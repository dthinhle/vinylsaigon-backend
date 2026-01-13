class CreateOrders < ActiveRecord::Migration[8.0]
  def change
    execute <<-SQL
      CREATE TYPE order_status AS ENUM ('awaiting_payment', 'paid', 'canceled', 'fulfilled', 'refunded', 'failed');
    SQL

    create_table :orders, id: :uuid do |t|
      t.bigint :user_id, null: true
      t.uuid :cart_id, null: true
      t.string :order_number, null: false

      t.enum :status, enum_type: 'order_status', default: 'awaiting_payment', null: false

      t.bigint :subtotal_vnd, default: 0, null: false
      t.bigint :shipping_vnd, default: 0, null: false
      t.bigint :tax_vnd, default: 0, null: false
      t.bigint :discount_vnd, default: 0, null: false
      t.bigint :total_vnd, default: 0, null: false
      t.string :currency, default: 'VND', null: false

      t.bigint :billing_address_id, null: true
      t.bigint :shipping_address_id, null: true

      t.jsonb :metadata, default: {}

      t.timestamps
    end

    add_index :orders, :order_number, unique: true
    add_index :orders, :user_id
    add_index :orders, :status
    add_index :orders, :cart_id

    add_foreign_key :orders, :users, column: :user_id
    add_foreign_key :orders, :carts, column: :cart_id
    add_foreign_key :orders, :addresses, column: :billing_address_id
    add_foreign_key :orders, :addresses, column: :shipping_address_id
  end
end
