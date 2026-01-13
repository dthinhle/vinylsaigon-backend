json.data @menu_items do |item|
  json.slug item.slug
  json.updated_at item.updated_at.iso8601
end
