class CreateProductVariants < ActiveRecord::Migration[8.0]
  def change
    create_table :product_variants do |t|
      t.references :product, null: false, foreign_key: true
      t.string :name, null: false
      t.string :sku, null: false
      t.decimal :price_adjustment, precision: 10, scale: 2
      t.integer :stock_quantity
      t.jsonb :variant_attributes, default: {}
      t.string :status, null: false, default: "active"
      t.integer :sort_order
      t.timestamps
    end

    add_index :product_variants, [:product_id, :sku], unique: true
  end
end
