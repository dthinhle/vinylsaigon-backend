class CreateBlogProducts < ActiveRecord::Migration[8.0]
  def change
    create_table :blog_products do |t|
      t.references :blog, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.datetime :deleted_at, index: true

      t.timestamps
    end
  end
end
