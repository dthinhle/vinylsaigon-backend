# frozen_string_literal: true

# == Schema Information
#
# Table name: product_images
#
#  id                 :bigint           not null, primary key
#  filename           :string
#  position           :integer          not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  product_variant_id :bigint           not null
#
# Indexes
#
#  index_product_images_on_filename            (filename)
#  index_product_images_on_product_variant_id  (product_variant_id)
#
# Foreign Keys
#
#  fk_rails_...  (product_variant_id => product_variants.id)
#
class ProductImage < ApplicationRecord
  belongs_to :product_variant
  acts_as_list scope: :product_variant

  validates :position, presence: true

  has_one_attached :image do |attachable|
    attachable.variant :thumbnail, format: :webp, resize_to_limit: [800, 800], preprocessed: true
  end

  before_save :set_filename

  def thumbnail_key
    processed_variant = image.variant(:thumbnail).processed

    processed_variant.image.blob.key
  end

  private

  def set_filename
    if image.attached? && filename != image.filename.to_s
      self.filename = image.filename.to_s
    end
  end
end
