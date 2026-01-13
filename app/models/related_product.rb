# == Schema Information
#
# Table name: related_products
#
#  id                 :bigint           not null, primary key
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  product_id         :bigint           not null
#  related_product_id :bigint           not null
#
# Indexes
#
#  index_related_products_on_product_id          (product_id)
#  index_related_products_on_related_product_id  (related_product_id)
#  index_related_products_unique                 (product_id,related_product_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (product_id => products.id)
#  fk_rails_...  (related_product_id => products.id)
#
class RelatedProduct < ApplicationRecord
  belongs_to :product
  belongs_to :related_product, class_name: 'Product'

  validates :product_id, uniqueness: { scope: :related_product_id }
  validate :prevent_self_linking

  after_create :create_reverse_link
  after_destroy :destroy_reverse_link

  private

  def prevent_self_linking
    if product_id == related_product_id
      errors.add(:base, 'Cannot link a product to itself')
    end
  end

  def create_reverse_link
    return if RelatedProduct.exists?(product_id: related_product_id, related_product_id: product_id)

    RelatedProduct.create!(
      product_id: related_product_id,
      related_product_id: product_id
    )
  end

  def destroy_reverse_link
    reverse = RelatedProduct.find_by(product_id: related_product_id, related_product_id: product_id)
    reverse&.delete
  end
end
