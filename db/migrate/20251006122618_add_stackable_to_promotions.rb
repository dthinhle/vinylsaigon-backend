class AddStackableToPromotions < ActiveRecord::Migration[8.0]
  def change
    add_column :promotions, :stackable, :boolean, default: false, null: false
  end
end
