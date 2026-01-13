class AddBlogsCountToBlogCategories < ActiveRecord::Migration[8.0]
  def up
    add_column :blog_categories, :blogs_count, :integer, default: 0, null: false

    # Reset counter cache for existing records
    BlogCategory.find_each do |category|
      BlogCategory.reset_counters(category.id, :blogs)
    end
  end

  def down
    remove_column :blog_categories, :blogs_count
  end
end
