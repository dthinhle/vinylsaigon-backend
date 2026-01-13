class AddSlugToProductVariants < ActiveRecord::Migration[7.0]
  def change
    add_column :product_variants, :slug, :string
    add_index :product_variants, :slug, unique: true
  end
end
