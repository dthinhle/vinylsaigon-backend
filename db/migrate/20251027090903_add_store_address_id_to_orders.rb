class AddStoreAddressIdToOrders < ActiveRecord::Migration[8.1]
  def change
    add_column :orders, :store_address_id, :bigint, null: true
    add_column :orders, :payment_method, :string
  end
end
