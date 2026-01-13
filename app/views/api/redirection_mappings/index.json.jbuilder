json.redirections do
  json.array! @redirection_mappings do |mapping|
    json.old_slug mapping.old_slug
    json.new_slug mapping.new_slug
  end
end
