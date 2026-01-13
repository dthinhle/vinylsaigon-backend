# frozen_string_literal: true

# Order partial for consistent JSON structure
json.extract! order, :id, :order_number, :status, :currency, :created_at,
  :updated_at, :email, :phone_number, :name, :shipping_method, :payment_method, :store_address_id

# Money fields in VND (integers)
json.subtotal_vnd order.subtotal_vnd
json.shipping_vnd order.shipping_vnd
json.tax_vnd order.tax_vnd
json.discount_vnd order.discount_vnd
json.total_vnd order.total_vnd

# Order items
json.items order.order_items do |item|
  json.extract! item, :id, :product_id, :product_variant_id, :product_name, :product_image_url,
    :quantity, :unit_price_vnd, :original_unit_price_vnd, :subtotal_vnd, :currency, :warranty_expire_date
  json.variant_name item.product_variant.name if item.product_variant.present?
  json.free_installment_fee item.product&.free_installment_fee || false
end

# Installment flags
json.installment_flags do
  json.has_free_installment order.has_free_installment_product?
  json.fully_free_installment order.fully_free_installment_order?
end

# Shipping address
if order.shipping_address.present?
  json.shipping_address do
    json.id order.shipping_address.id
    json.address order.shipping_address.address
    json.city order.shipping_address.city
    json.district order.shipping_address.district
    json.ward order.shipping_address.ward
    json.phone_numbers order.shipping_address.phone_numbers
    json.map_url order.shipping_address.map_url
  end
end

# Billing address
if order.billing_address.present?
  json.billing_address do
    json.id order.billing_address.id
    json.address order.billing_address.address
    json.city order.billing_address.city
    json.district order.billing_address.district
    json.ward order.billing_address.ward
    json.phone_numbers order.billing_address.phone_numbers
    json.map_url order.billing_address.map_url
  end
end

json.cart do
  json.partial! 'api/carts/cart', cart: order.cart
end
