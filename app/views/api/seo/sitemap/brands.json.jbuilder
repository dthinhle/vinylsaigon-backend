json.data @brands do |brand|
  json.slug brand.slug
  json.updated_at brand.updated_at.iso8601
end
