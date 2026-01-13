class AutoApplyBundlePromotionsService
  Result = Struct.new(:success?, :error_code, keyword_init: true)

  attr_reader :cart, :current_cart_promotions

  def initialize(cart)
    @cart = cart
  end

  def call
    return success unless cart.present?

    active_bundle_promotions = Promotion.active.bundle.includes(:product_bundles)
    @current_cart_promotions = cart.promotions.to_a

    applicable_promotions = active_bundle_promotions.select do |promotion|
      evaluator = BundlePromotionEvaluator.new(cart, promotion)
      evaluator.applicable?
    rescue StandardError => e
      Rails.logger.warn("Bundle evaluation error for promotion #{promotion.id}: #{e.class} - #{e.message}")
      false
    end

    applicable_promotions.each do |promotion|
      next if current_cart_promotions.any? { |p| p.id == promotion.id }

      if promotion.stackable? || current_cart_promotions.empty?
        cart.promotions << promotion if can_add_promotion?(promotion)
        current_cart_promotions << promotion
      end
    rescue StandardError => e
      Rails.logger.error("Failed to add bundle promotion #{promotion.id}: #{e.class} - #{e.message}")
      return failure(PromotionErrorCodes::BUNDLE_PROMOTION_ADD_FAILED)
    end

    remove_non_applicable_bundles(active_bundle_promotions)
    success
  rescue StandardError => e
    Rails.logger.error("AutoApplyBundlePromotionsService failed: #{e.class} - #{e.message}")
    failure(PromotionErrorCodes::AUTO_APPLY_BUNDLE_FAILED)
  end

  private

  def can_add_promotion?(promotion)
    return true if current_cart_promotions.empty?
    return false if current_cart_promotions.any? { |p| !p.stackable? }
    return false unless promotion.stackable?

    true
  end

  def remove_non_applicable_bundles(active_bundle_promotions)
    cart.promotions.bundle.each do |promotion|
      evaluator = BundlePromotionEvaluator.new(cart, promotion)

      cart.promotions.delete(promotion) unless evaluator.applicable?
    rescue StandardError => e
      Rails.logger.error("Failed to remove bundle promotion #{promotion.id}: #{e.class} - #{e.message}")
    end
  end

  def success
    Result.new(success?: true)
  end

  def failure(error_code)
    Result.new(success?: false, error_code: error_code)
  end
end
