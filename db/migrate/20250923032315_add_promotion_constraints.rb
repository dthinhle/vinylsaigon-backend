class AddPromotionConstraints < ActiveRecord::Migration[8.0]
  def change
    reversible do |dir|
      dir.up do
        add_check_constraint :promotions,
          "(starts_at IS NULL OR ends_at IS NULL OR starts_at <= ends_at)",
          name: "chk_promotions_starts_before_ends"

        add_check_constraint :promotions,
          "usage_count >= 0",
          name: "chk_promotions_usage_count_non_negative"

        add_check_constraint :promotions,
          "(usage_limit IS NULL OR usage_limit >= 0)",
          name: "chk_promotions_usage_limit_non_negative"

        add_check_constraint :promotions,
          "discount_value > 0",
          name: "chk_promotions_discount_value_positive"
      end

      dir.down do
        remove_check_constraint :promotions, name: "chk_promotions_starts_before_ends"
        remove_check_constraint :promotions, name: "chk_promotions_usage_count_non_negative"
        remove_check_constraint :promotions, name: "chk_promotions_usage_limit_non_negative"
        remove_check_constraint :promotions, name: "chk_promotions_discount_value_positive"
      end
    end
  end
end
