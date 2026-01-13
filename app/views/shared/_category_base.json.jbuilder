json.extract! category, :id, :title, :slug, :description, :is_root
json.index_path category.index_path

if category.parent
  json.parent do
    json.extract! category.parent, :id, :title, :slug
    if category.parent.image.attached?
      json.thumbnail do
        json.url ImagePathService.new(category.parent.image).path
      end
    else
      json.thumbnail nil
    end
  end
end
