json.data @products do |product|
  json.slug product.slug
  json.updated_at product.updated_at.iso8601
end
