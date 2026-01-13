json.data @categories do |category|
  json.slug category.slug
  json.updated_at category.updated_at.iso8601
end
