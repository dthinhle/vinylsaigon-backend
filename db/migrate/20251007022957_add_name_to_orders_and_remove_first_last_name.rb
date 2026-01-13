class AddNameToOrdersAndRemoveFirstLastName < ActiveRecord::Migration[8.0]
  def change
    add_column :orders, :name, :string
    remove_column :orders, :first_name, :string
    remove_column :orders, :last_name, :string
  end
end
