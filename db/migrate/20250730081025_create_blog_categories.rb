class CreateBlogCategories < ActiveRecord::Migration[8.0]
  def change
    create_table :blog_categories do |t|
      t.string :name, null: false
      t.string :slug, null: false, index: { unique: true }
      t.datetime :deleted_at, index: true

      t.timestamps
    end
  end
end
