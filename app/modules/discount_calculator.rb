# frozen_string_literal: true

module DiscountCalculator
  ROUND_VALUE = -3

  def self.calculate(subtotal, promotions, cart: nil)
    return {
      subtotal: subtotal,
      discount_amount: 0,
      bundle_discount: 0,
      final_total: subtotal
    } if promotions.empty?

    bundle_promos = promotions.select { |p| p.discount_type == 'bundle' }
    fixed_promos = promotions.select { |p| p.discount_type == 'fixed' }
    percentage_promos = promotions.select { |p| p.discount_type == 'percentage' }

    bundle_discount = calc_bundle_discounts(cart, bundle_promos).to_i
    remaining_after_bundles = subtotal - bundle_discount

    fixed_discount = calc_fixed_discounts(remaining_after_bundles, fixed_promos).to_i
    remaining_after_fixed = remaining_after_bundles - fixed_discount

    percentage_discount = calc_percentage_discount(remaining_after_fixed, percentage_promos).to_i

    total_discount = [bundle_discount + fixed_discount + percentage_discount, subtotal].min.round(ROUND_VALUE)

    {
      subtotal: subtotal,
      discount_amount: total_discount.to_i,
      bundle_discount: bundle_discount,
      final_total: [subtotal - total_discount, 0].max.to_i
    }
  end

  private

  def self.calc_bundle_discounts(cart, bundle_promos)
    if cart.nil? && bundle_promos.any?
      Rails.logger.warn('DiscountCalculator: Bundle promotions present but cart is nil')
      return 0
    end

    return 0 if bundle_promos.empty?

    bundle_promos.sum do |promo|
      evaluator = BundlePromotionEvaluator.new(cart, promo)
      evaluator.total_discount
    end
  end

  def self.calc_fixed_discounts(subtotal, fixed_promos)
    fixed_discount = fixed_promos.sum { |promo| promo.apply_amount(subtotal) }
    [fixed_discount, subtotal].min
  end

  def self.calc_percentage_discount(remaining_amount, percentage_promos)
    percentage_promos.inject(0) do |total_percent_discount, promo|
      current_amount_to_discount = remaining_amount - total_percent_discount
      total_percent_discount + promo.apply_amount(current_amount_to_discount)
    end
  end
end
