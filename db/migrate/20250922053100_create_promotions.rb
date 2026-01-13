class CreatePromotions < ActiveRecord::Migration[8.0]
  def change
    create_table :promotions do |t|
      t.string   :title,           null: false
      t.string   :code,            null: false
      t.datetime :starts_at
      t.datetime :ends_at
      t.string   :discount_type,   null: false
      t.decimal  :discount_value,  precision: 10, scale: 2, null: false
      t.boolean  :active,          default: true, null: false
      t.jsonb    :metadata
      t.integer  :usage_limit
      t.integer  :usage_count,     default: 0, null: false
      t.datetime :deleted_at

      t.timestamps
    end

    # Indexes
    # Case-insensitive unique index on lower(code) for PostgreSQL
    add_index :promotions, "lower(code)", unique: true, name: "index_promotions_on_lower_code"
    add_index :promotions, :active
    add_index :promotions, :starts_at
    add_index :promotions, :ends_at
    add_index :promotions, :deleted_at

    # Run with:
    #   rails db:migrate
  end
end
