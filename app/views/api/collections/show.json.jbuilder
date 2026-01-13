json.collection do
  json.extract! @collection, :id, :name, :slug, :description, :created_at, :updated_at
  json.banner_url @collection.banner.attached? ? rails_blob_url(@collection.banner) : nil

  json.categories do
    json.array! @collection.root_categories do |category|
      json.partial! 'shared/category_base', category: category

      # Include thumbnail image
      if category.image.attached?
        json.thumbnail do
          json.url rails_blob_url(category.image)
        end
      else
        json.thumbnail nil
      end

      child_categories = category.children.where(id: @collection.products.displayable.select(:category_id))
      json.children do
        if child_categories.any?
          json.array! child_categories do |child|
            json.partial! 'api/categories/child_category', child: child, active_subcategory: @active_subcategory
          end
        else
          json.array! []
        end
      end
    end
  end
end
