class CreateRedirectionMappings < ActiveRecord::Migration[8.0]
  def change
    create_table :redirection_mappings do |t|
      t.string :old_slug, null: false
      t.string :new_slug, null: false
      t.boolean :active, null: false

      t.timestamps
    end

    add_index :redirection_mappings, :old_slug, unique: true
    add_index :redirection_mappings, [:old_slug, :active]
  end
end
