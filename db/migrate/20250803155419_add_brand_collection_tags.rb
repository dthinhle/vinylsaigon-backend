class AddBrandCollectionTags < ActiveRecord::Migration[8.0]
  def change
    create_table :brands do |t|
      t.string :name, null: false
      t.datetime :deleted_at
      t.timestamps
    end
    add_index :brands, :deleted_at
    add_index :brands, :name, unique: true

    create_table :product_collections do |t|
      t.string :name, null: false
      t.string :description, limit: 80
      t.datetime :deleted_at
      t.timestamps
    end
    add_index :product_collections, :deleted_at
    add_index :product_collections, :name, unique: true

    create_table :product_tags do |t|
      t.string :name, null: false
      t.datetime :deleted_at
    t.timestamps
    end
    add_index :product_tags, :deleted_at
    add_index :product_tags, :name, unique: true

    add_reference :products, :brand, foreign_key: true, null: true
    add_reference :products, :category, foreign_key: true
    add_column :product_variants, :short_description, :string, limit: 80

    create_join_table :products, :product_collections do |t|
      t.index [:product_id, :product_collection_id], name: 'index_products_collections_on_product_and_collection_id'
      t.index [:product_collection_id, :product_id], name: 'index_products_collections_on_collection_and_product_id'
    end

    create_join_table :products, :product_tags do |t|
      t.index [:product_id, :product_tag_id]
      t.index [:product_tag_id, :product_id]
    end
  end
end
