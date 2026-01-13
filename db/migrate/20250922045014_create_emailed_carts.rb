class CreateEmailedCarts < ActiveRecord::Migration[8.0]
  def change
    execute <<-SQL
      CREATE TYPE recipient_type AS ENUM ('authenticated', 'anonymous');
    SQL

    create_table :emailed_carts, id: :uuid do |t|
      t.uuid :cart_id, null: false
      t.string :email, null: false
      t.datetime :sent_at, null: false
      t.string :access_token, null: false
      t.datetime :expires_at, null: false
      t.enum :recipient_type, enum_type: 'recipient_type', default: 'anonymous'
      t.datetime :accessed_at, null: true

      t.timestamps
    end

    add_index :emailed_carts, :access_token, unique: true
    add_index :emailed_carts, :email
    add_index :emailed_carts, :expires_at
    add_index :emailed_carts, :cart_id

    add_foreign_key :emailed_carts, :carts, column: :cart_id
  end
end
