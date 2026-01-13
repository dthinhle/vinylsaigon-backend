json.orders @orders do |order|
  json.partial! 'order', order: order
end

json.pagination do
  json.current_page @pagination[:current_page]
  json.per_page @pagination[:per_page]
  json.total_pages @pagination[:total_pages]
  json.total_count @pagination[:total_count]
end
