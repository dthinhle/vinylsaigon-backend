json.extract! @store, :name, :facebook_url, :youtube_url, :instagram_url
json.addresses do
  json.array! @addresses do |address|
    json.extract! address, :address, :ward, :district, :city, :map_url, :phone_numbers, :id
  end
end
