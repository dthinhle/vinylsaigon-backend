json.extract! product, :id, :name, :slug, :sku, :status, :stock_status, :stock_quantity, :weight, :meta_title, :meta_description, :warranty_months, :free_installment_fee

json.description product.description.to_json
json.short_description product.short_description.to_json

json.brands do
  json.array! product.brands do |brand|
    json.extract! brand, :name, :slug
  end
end

json.flags product.formatted_flags

json.product_attributes do
  if product.product_attributes.is_a?(Hash) && product.product_attributes['attributes'].is_a?(Array)
    # New format: array of {name, value}
    json.array! product.product_attributes['attributes'] do |attr|
      json.label attr['name']
      json.value attr['value']
    end
  else
    # Old format: hash of key => value
    json.array! product.product_attributes do |key, value|
      json.label key
      json.value value
    end
  end
end

first_variant_with_images = product.product_variants.find { |variant| variant.product_images.any? }

json.variants product.product_variants do |variant|
  json.partial! 'models/product_variant', product_variant: variant, first_variant_with_images: first_variant_with_images.try(:id) == variant.id ? nil : first_variant_with_images
end

if product.category
  json.category do
    json.partial! 'shared/category_base', category: product.category
  end
else
  json.category nil
end
