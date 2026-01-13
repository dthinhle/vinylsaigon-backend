class AddSlugToBrands < ActiveRecord::Migration[8.0]
  def change
    add_column :brands, :slug, :string
    add_index :brands, :slug, unique: true
  end
end
