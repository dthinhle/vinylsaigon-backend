json.extract! cart, :id, :session_id, :user_id, :guest_email, :status, :cart_type,
              :expires_at, :last_activity_at, :created_at, :updated_at

json.total_items cart.total_items
json.total_price cart.total_price

json.free_shipping cart.free_shipping?

json.items cart.cart_items.order(created_at: :asc) do |item|
  json.partial! 'api/carts/cart_item', cart_item: item
end

json.promotions cart.promotions.includes(product_bundles: :product) do |promo|
  json.extract! promo, :id, :code, :title, :discount_type, :discount_value, :max_discount_amount_vnd, :stackable

  if promo.bundle?
    json.bundle_items promo.product_bundles do |bundle_item|
      json.extract! bundle_item, :product_id, :product_variant_id, :quantity
      json.product_name bundle_item.product.name
      json.variant_name bundle_item.product_variant&.name
    end
  end
end

json.subtotal cart.subtotal
json.discount_total cart.discount_total
json.bundle_discount cart.bundle_discount
json.total cart.total
json.currency 'VND'

json.installment_flags do
  free_count = cart.cart_items.joins(:product).where(products: { free_installment_fee: true }).count
  total_count = cart.cart_items.count
  json.has_free_installment (free_count > 0)
  json.fully_free_installment (total_count > 0 && free_count == total_count)
  json.free_items_count free_count
  json.total_items_count total_count
end

if defined?(@auto_apply_error) && @auto_apply_error
  json.warning do
    json.error_code @auto_apply_error
  end
end
