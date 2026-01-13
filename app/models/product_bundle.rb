# == Schema Information
#
# Table name: product_bundles
#
#  id                 :bigint           not null, primary key
#  quantity           :integer          default(1), not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  product_id         :bigint           not null
#  product_variant_id :bigint
#  promotion_id       :bigint           not null
#
# Indexes
#
#  index_product_bundles_on_product_id          (product_id)
#  index_product_bundles_on_product_variant_id  (product_variant_id)
#  index_product_bundles_on_promotion_id        (promotion_id)
#
# Foreign Keys
#
#  fk_rails_...  (product_id => products.id)
#  fk_rails_...  (product_variant_id => product_variants.id)
#  fk_rails_...  (promotion_id => promotions.id)
#
class ProductBundle < ApplicationRecord
  belongs_to :promotion
  belongs_to :product
  belongs_to :product_variant, optional: true

  validates :quantity, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validate :variant_belongs_to_product

  def matches_cart_item?(cart_item)
    return false unless cart_item.product_id == product_id
    return true if product_variant_id.nil?
    cart_item.product_variant_id == product_variant_id
  end

  private

  def variant_belongs_to_product
    return if product_variant_id.nil?
    return if product_variant.nil?

    unless product_variant.product_id == product_id
      errors.add(:product_variant_id, 'must belong to the specified product')
    end
  end
end
