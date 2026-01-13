# frozen_string_literal: true

json.order do
  json.partial! 'api/orders/order', order: @order
end
