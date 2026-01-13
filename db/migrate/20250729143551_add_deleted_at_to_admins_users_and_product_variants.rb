class AddDeletedAtToAdminsUsersAndProductVariants < ActiveRecord::Migration[8.0]
  def change
    add_column :admins, :deleted_at, :datetime
    add_index :admins, :deleted_at

    add_column :users, :deleted_at, :datetime
    add_index :users, :deleted_at

    add_column :product_variants, :deleted_at, :datetime
    add_index :product_variants, :deleted_at
  end
end
