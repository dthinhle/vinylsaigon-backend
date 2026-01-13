class AddActiveToProductCollections < ActiveRecord::Migration[8.1]
  def change
    add_column :product_collections, :active, :boolean, default: true, null: false
  end
end
