class AddPriceUpdatedAtToProduct < ActiveRecord::Migration[8.1]
  def change
    add_column :products, :price_updated_at, :datetime
  end
end
