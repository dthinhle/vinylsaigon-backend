json.collections do
  json.array! @collections, partial: 'api/collections/collection', as: :collection
end
