# == Schema Information
#
# Table name: product_variants
#
#  id                 :bigint           not null, primary key
#  current_price      :decimal(, )
#  deleted_at         :datetime
#  name               :string           not null
#  original_price     :decimal(, )
#  short_description  :string(80)
#  sku                :string           not null
#  slug               :string
#  sort_order         :integer
#  status             :string           default("active"), not null
#  stock_quantity     :integer
#  variant_attributes :jsonb
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  product_id         :bigint           not null
#
# Indexes
#
#  index_product_variants_on_deleted_at          (deleted_at)
#  index_product_variants_on_product_id          (product_id)
#  index_product_variants_on_product_id_and_sku  (product_id,sku) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (product_id => products.id)
#
class ProductVariant < ApplicationRecord
  include DynamicJsonbAttributes
  include ArrayFormatAttributes
  dynamic_jsonb_attribute :variant_attributes

  validate :validate_variant_attributes_format

  has_paper_trail(
    versions: { class_name: 'PaperTrail::Version' },
    limit: 10,
    meta: {
      product_id: :product_id,
      transaction_id: ->(product) do
        controller_info = PaperTrail.request.controller_info
        return unless controller_info

        controller_info[:transaction_id]
      end
    }
  )

  belongs_to :product
  has_many :order_items, dependent: :nullify
  has_many :product_bundles, dependent: :destroy

  has_many :product_images, -> { order(position: :asc) }, dependent: :destroy

  # TODO: Keep for backward compatibility
  # has_many_attached :images, dependent: :purge_later

  before_validation :set_default_slug
  after_save :trigger_product_flag_management, if: :saved_change_to_prices?
  after_save :touch_price_updated_at, if: :saved_change_to_prices?
  after_update_commit :revalidate_product_cache
  before_destroy :delete_images

  accepts_nested_attributes_for :product_images, allow_destroy: true

  enum :status, {
    active: 'active',
    inactive: 'inactive',
    discontinued: 'discontinued'
  }, default: 'active', validate: true, scopes: true

  scope :displayable, -> { where(status: ['active', 'discontinued']) }

  validates :name, presence: true
  validates :sku, presence: true, uniqueness: { scope: :product_id }
  validates :slug, presence: true, uniqueness: { scope: :product_id, message: 'must be unique for this product. Please choose another slug.' }
  validates :original_price, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :current_price, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :stock_quantity, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :status, presence: true, inclusion: { in: statuses.keys }
  validates :sort_order, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true

  # Wrapper for dynamic_jsonb_attributes, returns its result
  def safe_variant_attributes
    dynamic_jsonb_attributes
  end

  def images
    ActiveStorage::Attachment.joins("INNER JOIN product_images ON product_images.id = active_storage_attachments.record_id AND active_storage_attachments.record_type = 'ProductImage' AND active_storage_attachments.name = 'image'")
                             .where(record_type: 'ProductImage', name: 'image', record_id: product_images.ids)
                             .order('product_images.position ASC')
  end

  def migrate_images
    return if images.blank? || product_images.size >= images.size

    ActiveRecord::Base.transaction do
      images.each_with_index do |image, index|
        product_image = product_images.where(filename: image.filename.to_s).first_or_create
        product_image.image = image.blob
        product_image.position = index + 1
        product_image.save!
      end
    end
  end

  def delete_images
    product_images.each do |pi|
      pi.image.purge_later if pi.image.attached?
      pi.destroy
    end
  end

  private

  def set_default_slug
    if slug.blank? && name.present?
      self.slug = Slugify.convert(name, true)
    end
  end

  def saved_change_to_prices?
    saved_change_to_original_price? || saved_change_to_current_price?
  end

  def trigger_product_flag_management
    had_no_price_before = (original_price_before_last_save.nil? && original_price.present?) ||
                          (current_price_before_last_save.nil? && current_price.present?)

    if had_no_price_before
      # WARNING: The method `product.add_just_arrived_flag_from_variant` must
      #          use `update_columns` (not `save` or `update`) to avoid
      #          triggering Product's callbacks and causing a potential
      #          infinite loop between Product and ProductVariant.
      product.add_just_arrived_flag_from_variant
    end

    product.touch
  end

  def revalidate_product_cache
     FrontendRevalidateJob.perform_later('Product', product_id)
  end

  def touch_price_updated_at
    product.touch(:price_updated_at)
  end

  def validate_variant_attributes_format
    validate_array_format_attributes(:variant_attributes)
  end
end
