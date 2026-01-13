class CreateProductBundles < ActiveRecord::Migration[8.1]
  def change
    create_table :product_bundles do |t|
      t.references :promotion, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.references :product_variant, null: true, foreign_key: true
      t.integer :quantity, null: false, default: 1

      t.timestamps
    end

    add_check_constraint :product_bundles, 'quantity > 0', name: 'chk_product_bundles_quantity_positive'
  end
end
