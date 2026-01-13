class AddWarrantyExpireDateToOrderItems < ActiveRecord::Migration[8.1]
  def change
    add_column :order_items, :warranty_expire_date, :datetime
  end
end
