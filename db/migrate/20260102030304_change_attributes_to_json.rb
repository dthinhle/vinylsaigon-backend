class ChangeAttributesToJson < ActiveRecord::Migration[8.1]
  def change
    change_column :products, :product_attributes, :json, using: 'product_attributes::json'
    change_column :product_variants, :variant_attributes, :json, using: 'variant_attributes::json'
  end
end
