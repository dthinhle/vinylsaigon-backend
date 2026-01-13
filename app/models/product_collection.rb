# == Schema Information
#
# Table name: product_collections
#
#  id          :bigint           not null, primary key
#  active      :boolean          default(TRUE), not null
#  deleted_at  :datetime
#  description :string(80)
#  name        :string           not null
#  slug        :string
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Indexes
#
#  index_product_collections_on_deleted_at  (deleted_at)
#  index_product_collections_on_name        (name) UNIQUE
#  index_product_collections_on_slug        (slug) UNIQUE
#
class ProductCollection < ApplicationRecord
  include Sluggable

  has_and_belongs_to_many :products

  has_one_attached :banner
  has_many :categories, through: :products

  has_one_attached :thumbnail do |attachable|
    attachable.variant :thumbnail, resize_to_limit: [800, 800], preprocessed: true
  end

  validates :name, presence: true, uniqueness: true
  validates :description, length: { maximum: 80 }

  scope :active, -> { where(active: true) }

  SEEDED_COLLECTION_NAMES = [
    I18n.t('collections.new_arrivals.name', locale: :vi),
    I18n.t('collections.on_sale.name', locale: :vi),
  ].freeze

  def seeded_collection?
    SEEDED_COLLECTION_NAMES.include?(name)
  end

  def root_categories
    categories.map { |category| category.is_root? ? category : category.parent }
              .compact
              .uniq
              .sort_by(&:title)
  end
end
