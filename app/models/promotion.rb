# == Schema Information
#
# Table name: promotions
#
#  id                      :bigint           not null, primary key
#  active                  :boolean          default(TRUE), not null
#  code                    :string           not null
#  deleted_at              :datetime
#  discount_type           :string           not null
#  discount_value          :decimal(10, 2)   not null
#  ends_at                 :datetime
#  max_discount_amount_vnd :bigint           default(0), not null
#  metadata                :jsonb
#  stackable               :boolean          default(FALSE), not null
#  starts_at               :datetime
#  title                   :string           not null
#  usage_count             :integer          default(0), not null
#  usage_limit             :integer
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#
# Indexes
#
#  index_promotions_on_active      (active)
#  index_promotions_on_deleted_at  (deleted_at)
#  index_promotions_on_ends_at     (ends_at)
#  index_promotions_on_lower_code  (lower((code)::text)) UNIQUE
#  index_promotions_on_starts_at   (starts_at)
#
class Promotion < ApplicationRecord
  enum :discount_type, { percentage: 'percentage', fixed: 'fixed', bundle: 'bundle' }

  before_validation :normalize_code

  validates :title, :code, :discount_type, :discount_value, presence: true
  validates :code, uniqueness: { case_sensitive: false }
  validates :code, length: { maximum: 64 }
  validates :discount_type, inclusion: { in: discount_types.keys }
  validates :discount_value, numericality: { greater_than: 0 }
  validates :usage_limit, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :usage_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :max_discount_amount_vnd, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :percentage_value_within_bounds
  validate :bundle_has_product_bundles
  validate :ends_cannot_be_in_the_past
  validate :starts_before_ends

  scope :active, -> {
    where(active: true).
      where('starts_at IS NULL OR starts_at <= ?', Time.current).
      where('ends_at IS NULL OR ends_at >= ?', Time.current)
  }
  scope :upcoming, -> { where('starts_at > ?', Time.current) }
  scope :expired, -> { where('ends_at < ?', Time.current) }
  scope :available, -> { active }

  has_many :promotion_usages, dependent: :restrict_with_error
  has_many :orders, through: :promotion_usages, source: :redeemable, source_type: 'Order'

  has_many :cart_promotions, dependent: :destroy
  has_many :carts, through: :cart_promotions

  has_many :product_bundles, dependent: :destroy
  accepts_nested_attributes_for :product_bundles, allow_destroy: true

  # Returns how many uses remain for this promotion. If usage_limit is nil returns Infinity.
  def remaining_uses
    return Float::INFINITY if usage_limit.nil?
    [usage_limit - usage_count, 0].max
  end

  # Returns true when the promotion has reached or exceeded its usage_limit.
  def used_up?
    return false if usage_limit.zero?

    usage_limit.present? && usage_count >= usage_limit
  end

  def applies_now?
    return false unless active
    (starts_at.nil? || starts_at <= Time.current) && (ends_at.nil? || ends_at >= Time.current)
  end

  # Returns the discount amount (how much should be subtracted) for the provided amount.
  # For percentage discounts returns amount * discount_value / 100, for fixed returns the lesser of
  # the fixed discount_value and the provided amount.
  def apply_amount(amount)
    return 0 unless amount.present? && discount_value.present?

    amt = BigDecimal(amount.to_s)

    if percentage?
      discount = (amt * BigDecimal(discount_value.to_s) / 100)
      if max_discount_amount_vnd.present? && max_discount_amount_vnd > 0
        cap = BigDecimal(max_discount_amount_vnd.to_s)
        [discount, cap].min.round(2)
      else
        discount.round(2)
      end
    else
      [BigDecimal(discount_value.to_s), amt].min.round(2)
    end
  end

  private

  def normalize_code
    self.code = code.to_s.strip.downcase.presence
  end

  def percentage_value_within_bounds
    return unless discount_type == 'percentage' && discount_value.present?

    if BigDecimal(discount_value.to_s) > BigDecimal('100')
      errors.add(:discount_value, 'must be less than or equal to 100 for percentage discounts')
    end
  end

  def bundle_has_product_bundles
    return unless discount_type == 'bundle'

    if product_bundles.reject(&:marked_for_destruction?).size < 2
      errors.add(:product_bundles, 'must have at least 2 products for bundle promotions')
    end
  end

  def ends_cannot_be_in_the_past
    return if ends_at.blank?

    if ends_at < Time.current
      errors.add(:ends_at, 'cannot be in the past')
    end
  end

  def starts_before_ends
    return if starts_at.blank? || ends_at.blank?

    if starts_at > ends_at
      errors.add(:starts_at, 'must be before or equal to ends at')
    end
  end
end
