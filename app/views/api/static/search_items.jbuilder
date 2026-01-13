json.popular_searches @popular_searches do |item|
  json.type item[:type]

  if item[:type] == 'product'
    json.extract! item[:item], :id, :name, :slug
  else
    json.extract! item[:item], :id, :title, :slug
  end
end

json.for_you_content @for_you_content do |item|
  json.type item[:type]

  if item[:type] == 'collection'
    json.extract! item[:item], :id, :name, :slug
  else
    json.extract! item[:item], :id, :title, :slug
  end
end
