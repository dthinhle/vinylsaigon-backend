class AddMoreColumnsToOrders < ActiveRecord::Migration[8.0]
  def change
    execute <<-SQL
      CREATE TYPE order_shipping_method AS ENUM ('ship_to_address', 'pick_up_at_store');
    SQL

    add_column :orders, :email, :string
    add_column :orders, :phone_number, :string
    add_column :orders, :first_name, :string
    add_column :orders, :last_name, :string
    add_column :orders, :shipping_method, :enum, enum_type: 'order_shipping_method', default: 'ship_to_address', null: false

    add_index :orders, :email
  end
end
