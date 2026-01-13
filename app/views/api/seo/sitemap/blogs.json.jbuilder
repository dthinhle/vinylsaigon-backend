json.data @blogs do |blog|
  json.slug blog.slug
  json.updated_at blog.updated_at.iso8601
end
