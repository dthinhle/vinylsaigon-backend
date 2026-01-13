class CreateCarts < ActiveRecord::Migration[8.0]
  def change
    execute <<-SQL
      CREATE TYPE cart_status AS ENUM ('active', 'expired', 'checked_out', 'emailed', 'abandoned');
      CREATE TYPE cart_type_enum AS ENUM ('authenticated', 'anonymous');
    SQL

    create_table :carts, id: :uuid do |t|
      t.bigint :user_id, null: true
      t.string :session_id, null: false
      t.string :guest_email, null: true

      t.enum :status, enum_type: 'cart_status', default: 'active'
      t.enum :cart_type, enum_type: 'cart_type_enum', default: 'anonymous'
      t.jsonb :metadata, default: {}

      t.timestamps
      t.datetime :expires_at, null: false
      t.datetime :last_activity_at, null: false
    end

    add_index :carts, :user_id, where: "user_id IS NOT NULL"
    add_index :carts, :session_id
    add_index :carts, :expires_at
    add_index :carts, [:status, :cart_type]
    add_index :carts, :last_activity_at
    add_index :carts, :guest_email

    add_foreign_key :carts, :users, column: :user_id
  end
end
