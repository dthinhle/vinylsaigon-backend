# == Schema Information
#
# Table name: brands
#
#  id         :bigint           not null, primary key
#  deleted_at :datetime
#  name       :string           not null
#  slug       :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_brands_on_deleted_at  (deleted_at)
#  index_brands_on_name        (name) UNIQUE
#  index_brands_on_slug        (slug) UNIQUE
#
class Brand < ApplicationRecord
  include Sluggable

  has_paper_trail(
    versions: { class_name: 'PaperTrail::Version' },
    limit: 10,
  )

  has_and_belongs_to_many :products
  has_many :categories, through: :products

  has_one_attached :logo do |attachable|
    attachable.variant :thumbnail, resize_to_limit: [800, 800], preprocessed: true
  end
  has_one_attached :banner

  validates :name, presence: true, uniqueness: true

  def logo_webp_small
    logo.variant(format: :webp, resize_to_limit: [120, 120]).processed
  end

  def logo_webp
    logo.variant(format: :webp, resize_to_limit: [800, 800]).processed
  end

  def root_categories
    categories.map { |category| category.is_root? ? category : category.parent }
              .compact
              .uniq
              .sort_by(&:title)
  end
end
