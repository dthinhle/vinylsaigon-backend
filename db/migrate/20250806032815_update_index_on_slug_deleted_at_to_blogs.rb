class UpdateIndexOnSlugDeletedAtToBlogs < ActiveRecord::Migration[8.0]
  def change
    remove_index :blogs, column: :slug, if_exists: true
    add_index :blogs, :slug, unique: true, where: 'deleted_at IS NULL'
  end
end
