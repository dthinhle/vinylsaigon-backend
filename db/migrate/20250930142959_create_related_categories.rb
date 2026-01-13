class CreateRelatedCategories < ActiveRecord::Migration[8.0]
  def change
    create_table :related_categories do |t|
      t.references :category, null: false, foreign_key: true
      t.references :related_category, null: false, foreign_key: { to_table: :categories }
      t.integer :weight, null: false

      t.timestamps
    end

    # Add indexes for performance
    add_index :related_categories, [:category_id, :related_category_id], unique: true, name: 'index_related_categories_unique'
  end
end
