class CreateBlogs < ActiveRecord::Migration[8.0]
  def change
    create_table :blogs do |t|
      t.string :title, null: false
      t.text :excerpt, limit: 500
      t.text :content
      t.datetime :published_at
      t.string :slug, null: false, index: { unique: true }
      t.string :status, null: false, default: "draft"
      t.string :meta_title, limit: 255
      t.string :meta_description, limit: 500
      t.references :author, null: false, foreign_key: { to_table: :admins }
      t.references :category, foreign_key: { to_table: :blog_categories }
      t.integer :view_count, default: 0
      t.datetime :deleted_at, index: true

      t.timestamps
    end
  end
end
