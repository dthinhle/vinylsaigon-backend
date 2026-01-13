class CreateCategories < ActiveRecord::Migration[8.0]
  def change
    create_table :categories do |t|
      t.string :title
      t.string :description
      t.string :slug
      t.boolean :is_root, default: false
      t.references :parent, foreign_key: { to_table: :categories }
      t.string :button_text
      t.datetime :deleted_at, index: true

      t.timestamps
    end
  end
end
