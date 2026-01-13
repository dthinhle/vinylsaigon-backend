# Extract all attributes except content, which we handle separately
json.extract! blog, :id, :title, :slug, :short_description, :status, :view_count, :meta_title, :meta_description, :created_at, :updated_at, :published_at

if action_name == 'show'
  # Return raw Lexical JSON content for frontend rendering
  json.content blog.content
else
 # For list views, we might want to provide a preview or simplified content
 json.content_preview blog.short_description(150)
end

if blog.image.attached?
  json.image_url rails_blob_url(blog.image)
else
  json.image_url blog.first_content_image_url
end

if blog.author
  json.author blog.author.name
else
  json.author nil
end


json.category do
  if blog.category
    json.extract! blog.category, :slug, :name
  else
    nil
  end
end
