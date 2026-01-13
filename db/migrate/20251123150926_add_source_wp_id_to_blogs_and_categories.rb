class AddSourceWpIdToBlogsAndCategories < ActiveRecord::Migration[8.1]
  def change
    add_column :blogs, :source_wp_id, :bigint
    add_index :blogs, :source_wp_id, unique: true

    add_column :blog_categories, :source_wp_id, :bigint
    add_index :blog_categories, :source_wp_id, unique: true
  end
end
