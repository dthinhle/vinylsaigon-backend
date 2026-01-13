json.extract! banner, :id, :main_title, :description, :text_color, :url

if banner.image.attached?
  json.image do
    json.url ImagePathService.new(banner.image).path
    json.filename banner.image.filename
    json.content_type banner.image.content_type
    json.byte_size banner.image.byte_size
  end
else
  json.image nil
end
