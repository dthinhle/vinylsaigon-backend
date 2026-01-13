class RemoveProductTagsTableAndAddProductTagsArrayToProducts < ActiveRecord::Migration[8.1]
  def up
    add_column :products, :product_tags, :string, array: true, default: []

    execute <<-SQL.squish
      UPDATE products
      SET product_tags = COALESCE(
        (
          SELECT ARRAY_AGG(pt.name ORDER BY pt.name)
          FROM product_tags pt
          INNER JOIN product_tags_products ptp ON ptp.product_tag_id = pt.id
          WHERE ptp.product_id = products.id
        ),
        ARRAY[]::varchar[]
      )
    SQL

    drop_table :product_tags_products
    drop_table :product_tags
  end

  def down
    create_table :product_tags do |t|
      t.string :name, null: false
      t.datetime :deleted_at
      t.timestamps
    end
    add_index :product_tags, :name, unique: true
    add_index :product_tags, :deleted_at

    create_table :product_tags_products, id: false do |t|
      t.bigint :product_id, null: false
      t.bigint :product_tag_id, null: false
    end
    add_index :product_tags_products, [:product_id, :product_tag_id]
    add_index :product_tags_products, [:product_tag_id, :product_id]

    remove_column :products, :product_tags
  end
end
