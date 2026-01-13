# frozen_string_literal: true

# Service to validate and apply a single promotion code to a redeemable object
# (e.g., a Cart or Order) that supports multiple promotions.
#
# Usage:
#   result = ApplyPromotionCodeService.new(redeemable: cart, code: 'SUMMER20').call
#   if result.success?
#     # Promotion code applied successfully
#   else
#     # Handle error
#     puts result.error_code
#   end
class ApplyPromotionCodeService
  Result = Struct.new(:success?, :error_code, keyword_init: true)

  attr_reader :redeemable, :code, :user, :promotion

  # @param redeemable [#promotions] An object that can have promotions, typically a Cart or Order.
  # @param code [String] The promotion code being applied.
  # @param user [User] The user applying the promotion.
  def initialize(redeemable:, code:, user: nil)
    @redeemable = redeemable
    @code = code.to_s.strip.downcase
    @user = user || (redeemable.respond_to?(:user) ? redeemable.user : nil)
  end

  def call
    ActiveRecord::Base.transaction do
      @promotion = Promotion.find_by('lower(code) = ?', code)

      return failure(PromotionErrorCodes::PROMOTION_NOT_FOUND) unless promotion

      promotion.lock!

      return failure(PromotionErrorCodes::PROMOTION_INACTIVE) unless promotion.applies_now?
      return failure(PromotionErrorCodes::PROMOTION_USAGE_LIMIT_REACHED) if promotion.used_up?

      if redeemable.promotions.include?(promotion)
        return failure(PromotionErrorCodes::PROMOTION_ALREADY_APPLIED)
      end

      unless promotion.stackable?
        if redeemable.promotions.first
          return failure(PromotionErrorCodes::PROMOTION_NOT_STACKABLE)
        end
      end

      if redeemable.promotions.find { |p| !p.stackable? }
        return failure(PromotionErrorCodes::PROMOTION_NOT_STACKABLE)
      end

      apply_promotion
    end

    success
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "ApplyPromotionCodeService failed due to validation: #{e.message}"
    failure(PromotionErrorCodes::PROMOTION_VALIDATION_ERROR)
  rescue StandardError => e
    Rails.logger.error "ApplyPromotionCodeService failed with unexpected error: #{e.class}: #{e.message}"
    failure(PromotionErrorCodes::PROMOTION_UNEXPECTED_ERROR)
  end

  private

  def apply_promotion
    redeemable.promotions << promotion

    if redeemable.respond_to?(:recalculate_totals!)
      redeemable.recalculate_totals!
    end
  end

  def success
    Result.new(success?: true)
  end

  def failure(error_code)
    Result.new(success?: false, error_code: error_code)
  end
end
