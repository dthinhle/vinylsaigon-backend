json.promotion_id product_bundle.id
json.discount_value product_bundle.discount_value

other_products = product_bundle.product_bundles.includes(:product).reject { |bi| bi.product_id == current_product.id }

json.other_products other_products do |bundle_item|
  json.product_name bundle_item.product.name
  json.product_slug bundle_item.product.slug
  json.quantity bundle_item.quantity
end
