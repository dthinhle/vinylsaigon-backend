class ChangeAttributesToJsonb < ActiveRecord::Migration[8.1]
  def change
    change_column :products, :product_attributes, :jsonb, using: 'product_attributes::jsonb'
    change_column :product_variants, :variant_attributes, :jsonb, using: 'variant_attributes::jsonb'
  end
end
