class AddGiftContentToProducts < ActiveRecord::Migration[8.0]
  def change
    add_column :products, :gift_content, :text
    add_column :product_collections, :slug, :string
    add_index :product_collections, :slug, unique: true
  end
end
