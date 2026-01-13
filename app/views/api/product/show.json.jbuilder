json.partial! 'models/product', product: @product

json.product_bundles @product_bundles do |bundle|
  json.partial! 'models/product_bundle', product_bundle: bundle, current_product: @product
end

json.related_products @related_products, partial: 'models/simple_product', as: :product
json.other_products @other_products, partial: 'models/simple_product', as: :product
