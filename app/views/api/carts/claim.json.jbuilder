json.message 'Cart successfully claimed'
json.cart do
  json.partial! 'api/carts/cart', cart: @cart
end
