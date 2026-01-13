class HandleMultipleBrandProduct < ActiveRecord::Migration[8.0]
  def change
    remove_reference :products, :brand, foreign_key: true, null: true
    create_join_table :brands, :products do |t|
      t.index [:brand_id, :product_id], name: 'index_brands_products_on_brand_and_product_id'
      t.index [:product_id, :brand_id], name: 'index_brands_products_on_product_and_brand_id'
    end
  end
end
