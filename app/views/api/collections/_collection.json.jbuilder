json.extract! collection, :id, :name, :slug, :description, :created_at, :updated_at
json.banner_url collection.banner.attached? ? rails_blob_url(collection.banner) : nil
json.thumbnail_url collection.thumbnail.attached? ? rails_blob_url(collection.thumbnail) : nil
json.products_count collection.products.active.count
