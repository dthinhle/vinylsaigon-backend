json.brands do
  json.array! @brands, partial: 'api/models/brand', as: :brand
end
