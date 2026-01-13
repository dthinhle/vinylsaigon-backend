if @cart_item
  json.cart_item do
    json.partial! 'api/carts/cart_item', cart_item: @cart_item
  end
else
  json.message 'Item removed from cart'
end

json.cart do
  json.partial! 'api/carts/cart', cart: @cart
end
