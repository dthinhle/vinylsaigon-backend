class AddLegacyAttributesToProducts < ActiveRecord::Migration[8.1]
  def change
    add_column :products, :legacy_wp_id, :integer
    add_column :products, :legacy_attributes, :jsonb
  end
end
