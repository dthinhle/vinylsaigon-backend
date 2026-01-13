class AddProductAttributesToProducts < ActiveRecord::Migration[8.0]
  def change
    add_column :products, :product_attributes, :jsonb, default: {}
  end
end
