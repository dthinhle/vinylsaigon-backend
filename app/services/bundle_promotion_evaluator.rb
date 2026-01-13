class BundlePromotionEvaluator
  attr_reader :cart, :bundle_promotion

  def initialize(cart, bundle_promotion)
    @cart = cart
    @bundle_promotion = bundle_promotion
  end

  def applicable?
    return false unless bundle_promotion.bundle?
    return false if bundle_promotion.product_bundles.empty?

    complete_sets_count > 0
  end

  def complete_sets_count
    @complete_sets_count ||= calculate_complete_sets
  end

  def total_discount
    return 0 unless applicable?

    base_discount = bundle_promotion.discount_value || 0
    (base_discount * complete_sets_count).to_i
  end

  private

  def calculate_complete_sets
    cart_items_by_bundle = bundle_promotion.product_bundles.map do |product_bundle|
      matching_items = cart.cart_items.select { |item| product_bundle.matches_cart_item?(item) }
      total_quantity = matching_items.sum(&:quantity)

      (total_quantity / product_bundle.quantity).floor
    end

    cart_items_by_bundle.min || 0
  end
end
