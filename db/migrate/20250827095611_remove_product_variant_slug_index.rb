class RemoveProductVariantSlugIndex < ActiveRecord::Migration[8.0]
  def change
    remove_index :product_variants, :slug, unique: true
  end
end
