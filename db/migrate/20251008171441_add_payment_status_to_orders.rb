class AddPaymentStatusToOrders < ActiveRecord::Migration[8.0]
  def change
    add_column :orders, :payment_status, :string, default: 'pending', null: false
    add_index :orders, :payment_status
  end
end
