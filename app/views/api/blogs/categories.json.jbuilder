json.array! @categories do |category|
  json.id category.id
  json.name category.name
  json.slug category.slug
  json.created_at category.created_at
  json.updated_at category.updated_at
  json.blogs_count category.blogs_count
end
