json.related_products do
  json.array! @related_products, partial: 'models/simple_product', as: :product
end
