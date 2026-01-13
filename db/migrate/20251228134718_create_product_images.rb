class CreateProductImages < ActiveRecord::Migration[8.1]
  def change
    create_table :product_images do |t|
      t.string :filename
      t.references :product_variant, null: false, foreign_key: true
      t.integer :position, null: false

      t.timestamps
    end

    add_index :product_images, :filename
  end
end
