json.data @collections do |collection|
  json.slug collection.slug
  json.updated_at collection.updated_at.iso8601
end
