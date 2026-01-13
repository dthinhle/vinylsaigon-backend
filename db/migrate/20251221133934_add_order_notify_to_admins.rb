class AddOrderNotifyToAdmins < ActiveRecord::Migration[8.1]
  def change
    add_column :admins, :order_notify, :boolean, default: false, null: false
  end
end
