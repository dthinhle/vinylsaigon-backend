class AddSlugAndFlagsToProducts < ActiveRecord::Migration[8.0]
  def change
    add_column :products, :slug, :string
    add_index :products, :slug, unique: true
    add_column :products, :flags, :string, array: true, default: []
  end
end
