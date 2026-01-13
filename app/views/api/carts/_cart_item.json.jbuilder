json.extract! cart_item, :id, :product_id, :product_name,
              :product_image_url, :quantity, :current_price, :original_price,
              :currency, :added_at, :expires_at

json.line_total cart_item.line_total
json.price_changed cart_item.price_changed?
json.current_market_price cart_item.current_market_price
json.savings cart_item.savings
json.free_installment_fee cart_item.product&.free_installment_fee || false
json.variant do
  if cart_item.product_variant
    variant = cart_item.product_variant
    json.id variant.id
    json.name variant.name
    json.sku variant.sku
  else
    json.null!
  end
end
