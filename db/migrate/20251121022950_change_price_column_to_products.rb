class ChangePriceColumnToProducts < ActiveRecord::Migration[8.1]
  def change
    change_column :product_variants, :original_price, :decimal
    change_column :product_variants, :current_price, :decimal
  end
end
