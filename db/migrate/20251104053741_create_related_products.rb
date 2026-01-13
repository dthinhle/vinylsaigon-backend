class CreateRelatedProducts < ActiveRecord::Migration[8.1]
  def change
    create_table :related_products do |t|
      t.references :product, null: false, foreign_key: true
      t.references :related_product, null: false, foreign_key: { to_table: :products }

      t.timestamps
    end

    add_index :related_products, [:product_id, :related_product_id], unique: true, name: 'index_related_products_unique'
  end
end
