class CreateCartPromotions < ActiveRecord::Migration[8.0]
  def change
    create_table :cart_promotions do |t|
      t.references :cart, null: false, foreign_key: true, type: :uuid
      t.references :promotion, null: false, foreign_key: true

      t.timestamps
    end
  end
end
