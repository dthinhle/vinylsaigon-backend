class CreatePromotionUsages < ActiveRecord::Migration[8.0]
  def change
    create_table :promotion_usages do |t|
      t.bigint :promotion_id, null: false
      t.bigint :user_id
      t.string :redeemable_type
      t.bigint :redeemable_id
      t.jsonb :metadata, default: {}
      t.boolean :active, default: true, null: false

      t.timestamps
    end

    add_index :promotion_usages, :promotion_id
    add_index :promotion_usages, [:promotion_id, :user_id]
    add_index :promotion_usages, [:promotion_id, :created_at]

    add_foreign_key :promotion_usages, :promotions, column: :promotion_id, on_delete: :restrict
  end
end
