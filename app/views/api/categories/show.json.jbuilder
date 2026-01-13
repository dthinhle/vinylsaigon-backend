json.partial! 'models/category', category: @category

# Add is_active field for the root category
json.is_active !defined?(@active_subcategory)

# Include children with their complete information
if @category.children.any?
  json.children @category.children do |child|
    json.partial! 'api/categories/child_category', child: child, active_subcategory: @active_subcategory
  end
end
