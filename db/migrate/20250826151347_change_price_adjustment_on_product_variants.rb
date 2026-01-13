class ChangePriceAdjustmentOnProductVariants < ActiveRecord::Migration[8.0]
  def change
    rename_column :product_variants, :price_adjustment, :price
  end
end
