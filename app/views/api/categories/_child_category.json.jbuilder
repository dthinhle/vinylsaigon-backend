json.extract! child, :id, :title, :description, :slug, :is_root, :button_text

# Set is_active true for the originally requested subcategory
json.is_active active_subcategory&.id == child.id

if child.image.attached?
  json.thumbnail do
    json.url ImagePathService.new(child.image).path
  end
else
  json.thumbnail nil
end
