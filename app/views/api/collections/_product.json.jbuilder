json.extract! product, :id, :name, :slug, :short_description, :original_price, :current_price, :status, :featured, :flags, :gift_content, :created_at, :updated_at
json.images product.images.map { |img| rails_blob_url(img) }
json.category product.category&.title
json.brands product.brands.map(&:name)
