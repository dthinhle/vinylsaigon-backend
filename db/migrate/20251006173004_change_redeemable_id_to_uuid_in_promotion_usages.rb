class ChangeRedeemableIdToUuidInPromotionUsages < ActiveRecord::Migration[8.0]
  def change
    remove_column :promotion_usages, :redeemable_id, :bigint
    add_column :promotion_usages, :redeemable_id, :uuid
  end
end
