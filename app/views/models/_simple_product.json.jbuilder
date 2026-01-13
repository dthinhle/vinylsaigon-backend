json.extract! product, :id, :name, :sku, :slug

json.brands product.brands.pluck(:name)
json.collections product.product_collections.pluck(:name)

json.variants do
  # Only include the first variant with limited details
  # because frontend doesn't include variants in simple product view
  json.array! product.product_variants.first(1) do |variant|
    json.extract! variant, :id, :name, :short_description, :original_price, :current_price
    json.variant_attributes do
      if variant.variant_attributes.is_a?(Hash) && variant.variant_attributes['attributes'].is_a?(Array)
        # New format: array of {name, value}
        json.array! variant.variant_attributes['attributes'] do |attr|
          json.label attr['name']
          json.value attr['value']
        end
      else
        # Old format: hash of key => value
        json.array! variant.variant_attributes do |key, value|
          json.label key
          json.value value
        end
      end
    end

    # Only include the first 2 images in simple product view
    json.images variant.product_images.first(2).map { |product_image| ImagePathService.new(product_image.image).path }
  end
end
