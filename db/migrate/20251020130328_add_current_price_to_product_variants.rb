class AddCurrentPriceToProductVariants < ActiveRecord::Migration[8.0]
  def up
    add_column :product_variants, :current_price, :decimal, precision: 10, scale: 2
    rename_column :product_variants, :price, :original_price

    Product.find_each do |product|
      next unless product.product_variants.any?

      default_variant = product.product_variants.first
      default_variant.update_columns(
        original_price: product.original_price || 0,
        current_price: product.current_price
      )
    end

    remove_column :products, :original_price
    remove_column :products, :current_price
  end

  def down
    add_column :products, :original_price, :decimal, precision: 10, scale: 2, null: false, default: 0
    add_column :products, :current_price, :decimal, precision: 10, scale: 2

    Product.find_each do |product|
      default_variant = product.product_variants.first
      next unless default_variant

      product.update_columns(
        original_price: default_variant.original_price || 0,
        current_price: default_variant.current_price
      )
    end

    rename_column :product_variants, :original_price, :price
    remove_column :product_variants, :current_price
  end
end
