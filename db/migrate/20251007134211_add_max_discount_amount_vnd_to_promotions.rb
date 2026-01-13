class AddMaxDiscountAmountVndToPromotions < ActiveRecord::Migration[8.0]
  def change
    add_column :promotions, :max_discount_amount_vnd, :bigint, default: 0, null: false
  end
end
