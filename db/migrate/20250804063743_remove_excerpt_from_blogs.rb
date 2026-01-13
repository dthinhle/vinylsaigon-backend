class RemoveExcerptFromBlogs < ActiveRecord::Migration[8.0]
  def up
    remove_column :blogs, :excerpt, :text
  end

  def down
    add_column :blogs, :excerpt, :text, limit: 500
  end
end
