json.partial! 'shared/category_base', category: category
json.extract! category, :button_text

# Include thumbnail image
if category.image.attached?
  json.thumbnail do
    json.url ImagePathService.new(category.image).path
  end
else
  json.thumbnail nil
end

json.children do
  if category.children.any?
    json.array! category.children do |child|
      json.extract! child, :id, :title, :description, :slug
      json.thumbnail do
        if child.image.attached?
          json.url ImagePathService.new(child.image).path
        else
          json.url nil
        end
      end
    end
  else
    json.array! []
  end
end
