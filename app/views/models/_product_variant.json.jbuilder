json.extract! product_variant, :id, :name, :sku, :slug, :current_price, :original_price, :stock_quantity, :status

json.variant_attributes do
  if product_variant.variant_attributes.is_a?(Hash) && product_variant.variant_attributes['attributes'].is_a?(Array)
    # New format: array of {name, value}
    json.array! product_variant.variant_attributes['attributes'] do |attr|
      json.label attr['name']
      json.value attr['value']
    end
  else
    # Old format: hash of key => value
    json.array! product_variant.variant_attributes do |key, value|
      json.label key
      json.value value
    end
  end
end

if product_variant.images.present?
  json.images do
    json.array! product_variant.images do |image|
      json.url ImagePathService.new(image).path
    end
  end
elsif defined?(first_variant_with_images) && first_variant_with_images.present?
  json.images do
    json.array! first_variant_with_images.images do |image|
      json.url ImagePathService.new(image).path
    end
  end
else
  json.images nil
end
