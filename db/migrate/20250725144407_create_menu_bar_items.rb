class CreateMenuBarItems < ActiveRecord::Migration[8.0]
  def change
    create_table :menu_bar_sections do |t|
      t.string :section_type, null: false

      t.timestamps
    end
    add_index :menu_bar_sections, :section_type, unique: true

    create_table :menu_bar_items do |t|
      t.references :menu_bar_section, null: false, foreign_key: true
      t.references :parent, foreign_key: { to_table: :menu_bar_items }
      t.string :item_type, null: false
      t.string :label, null: false
      t.string :link
      t.string :image
      t.integer :position, null: false

      t.timestamps
    end

    add_index :menu_bar_items, :position
  end
end
