json.partial! 'api/models/brand', brand: @brand

json.categories do
  json.array! @brand.root_categories do |category|
    json.partial! 'shared/category_base', category: category

    # Include thumbnail image
    if category.image.attached?
      json.thumbnail do
        json.url ImagePathService.new(category.image).path
      end
    else
      json.thumbnail nil
    end

    # Include children with their complete information
    child_categories = category.children.where(id: @brand.products.displayable.select(:category_id))
    if child_categories.any?
      json.children child_categories do |child|
        json.partial! 'api/categories/child_category', child: child, active_subcategory: @active_subcategory
      end
    end
  end
end
