class ConvertRichTextColumnsToJsonb < ActiveRecord::Migration[8.1]
  def up
    execute "ALTER TABLE products DROP COLUMN description"
    execute "ALTER TABLE products DROP COLUMN gift_content"
    execute "ALTER TABLE blogs DROP COLUMN content"

    execute "ALTER TABLE products ADD COLUMN description JSONB DEFAULT '{}' NOT NULL"
    execute "ALTER TABLE products ADD COLUMN gift_content JSONB DEFAULT '{}' NOT NULL"
    execute "ALTER TABLE blogs ADD COLUMN content JSONB DEFAULT '{}' NOT NULL"
  end

  def down
    execute "ALTER TABLE products DROP COLUMN description"
    execute "ALTER TABLE products DROP COLUMN gift_content"
    execute "ALTER TABLE blogs DROP COLUMN content"

    execute "ALTER TABLE products ADD COLUMN description TEXT"
    execute "ALTER TABLE products ADD COLUMN gift_content TEXT"
    execute "ALTER TABLE blogs ADD COLUMN content TEXT"
  end
end
