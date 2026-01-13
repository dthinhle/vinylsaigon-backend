class AddCategoryTitleIndex < ActiveRecord::Migration[8.0]
  def up
    add_index :categories, :title

    # Add constraint to ensure only root categories can be parents
    # Using a trigger-based approach since PostgreSQL doesn't allow subqueries in CHECK constraints
    execute <<~SQL
      CREATE OR REPLACE FUNCTION check_category_parent() RETURNS TRIGGER AS $$
      BEGIN
        IF NEW.parent_id IS NOT NULL THEN
          IF NOT EXISTS (SELECT 1 FROM categories WHERE id = NEW.parent_id AND is_root = true) THEN
            RAISE EXCEPTION 'Parent category must be a root category';
          END IF;
        END IF;
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;

      CREATE TRIGGER category_parent_check
        BEFORE INSERT OR UPDATE ON categories
        FOR EACH ROW EXECUTE FUNCTION check_category_parent();
    SQL
  end

  def down
    execute <<~SQL
      DROP TRIGGER IF EXISTS category_parent_check ON categories;
      DROP FUNCTION IF EXISTS check_category_parent();
    SQL

    remove_index :categories, :title
  end
end
