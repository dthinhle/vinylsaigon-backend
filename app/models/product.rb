# == Schema Information
#
# Table name: products
#
#  id                   :bigint           not null, primary key
#  deleted_at           :datetime
#  description          :jsonb            not null
#  featured             :boolean          default(FALSE), not null
#  flags                :string           default([]), is an Array
#  free_installment_fee :boolean          default(TRUE), not null
#  gift_content         :jsonb            not null
#  legacy_attributes    :jsonb
#  low_stock_threshold  :integer          default(5), not null
#  meta_description     :string(500)
#  meta_title           :string(255)
#  name                 :string           not null
#  price_updated_at     :datetime
#  product_attributes   :jsonb
#  product_tags         :string           default([]), is an Array
#  short_description    :jsonb            not null
#  sku                  :string           not null
#  slug                 :string
#  sort_order           :integer          default(0), not null
#  status               :string           default("inactive"), not null
#  stock_quantity       :integer          default(0), not null
#  stock_status         :string           default("in_stock"), not null
#  warranty_months      :integer
#  weight               :decimal(8, 2)
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  category_id          :bigint
#  legacy_wp_id         :integer
#
# Indexes
#
#  index_products_on_category_id  (category_id)
#  index_products_on_deleted_at   (deleted_at)
#  index_products_on_sku          (sku) UNIQUE
#  index_products_on_slug         (slug) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (category_id => categories.id)
#
class Product < ApplicationRecord
  include DynamicJsonbAttributes
  include ArrayFormatAttributes
  include Sluggable

  LEXICAL_COLUMNS = %w[short_description description gift_content].freeze

  dynamic_jsonb_attribute :product_attributes

  validate :validate_product_attributes_format

  has_paper_trail(
    versions: { class_name: 'PaperTrail::Version' },
    limit: 10,
    meta: {
      product_id: :id,
      transaction_id: ->(product) do
        controller_info = PaperTrail.request.controller_info
        return unless controller_info

        controller_info[:transaction_id]
      end
    }
  )

  attr_accessor :skip_auto_flags

  belongs_to :category, optional: true

  has_and_belongs_to_many :product_collections
  has_and_belongs_to_many :brands

  has_many :product_links, class_name: 'RelatedProduct', foreign_key: 'product_id', dependent: :destroy
  has_many :related_products, through: :product_links, source: :related_product
  has_many :cart_items, dependent: :destroy
  has_many :product_bundles, dependent: :destroy
  has_many :order_items, dependent: :nullify

  FLAGS = {
    not_free_shipping: 'not free shipping',
    backorder: 'backorder',
    arrive_soon: 'arrive soon',
    just_arrived: 'just arrived'
  }.freeze

  has_many :product_variants, -> { order(sku: :asc) }, dependent: :destroy
  accepts_nested_attributes_for :product_variants, allow_destroy: true, update_only: false
  has_many :blog_products, dependent: :destroy
  has_many :blogs, through: :blog_products

  has_many_attached :videos, dependent: :purge_later
  has_many_attached :content_images, dependent: :purge_later
  has_many_attached :content_videos, dependent: :purge_later

  enum :status, {
    active: 'active',
    inactive: 'inactive',
    discontinued: 'discontinued',
    temporarily_unavailable: 'temporarily_unavailable'
  }, default: 'inactive', validate: true, scopes: true

  enum :stock_status, {
    in_stock: 'in_stock',
    out_of_stock: 'out_of_stock',
    low_stock: 'low_stock'
  }, default: 'in_stock', validate: true, scopes: true

  validates :name, presence: true
  validates :sku, presence: true, uniqueness: true
  validates :status, presence: true

  validates :stock_status, presence: true
  validates :stock_quantity, numericality: { greater_than_or_equal_to: 0 }
  validates :low_stock_threshold, numericality: { greater_than_or_equal_to: 0 }
  validates :meta_title, length: { maximum: 255 }, allow_blank: true
  validates :meta_description, length: { maximum: 500 }, allow_blank: true

  validate :flags_inclusion
  validate :validate_product_variants

  scope :on_sale, -> {
    joins(:product_variants)
      .where('product_variants.current_price IS NOT NULL AND product_variants.original_price IS NOT NULL AND product_variants.current_price < product_variants.original_price')
      .distinct
  }
  scope :free_installment, -> { where(free_installment_fee: true) }
  scope :displayable, -> { where(status: %w[active discontinued temporarily_unavailable]) }

  MAX_ATTRIBUTE_DISPLAY_LENGTH = 100

  before_validation :sanitize_product_tags
  before_validation :sanitize_flags
  after_create :ensure_default_variant
  after_save :handle_post_save_updates
  after_destroy :trigger_collection_update
  after_commit :reindex, on: [:create, :update, :destroy]
  after_update_commit :revalidate_frontend_cache

  def images
    @product_images ||= product_variants.flat_map(&:images)
  end

  def current_price
    return nil unless persisted?

    @current_price ||= product_variants.size > 1 ? product_variants.pluck(:current_price).compact.min : product_variants.first&.current_price
  end

  def current_price=(value)
    @current_price = value
  end

  def original_price
    return nil unless persisted?

    @original_price ||= product_variants.size > 1 ? product_variants.pluck(:original_price).compact.max : product_variants.first&.original_price
  end

  def original_price=(value)
    @original_price = value
  end

  # Called from ProductVariant when prices are first set on a variant.
  # Adds "just arrived" flag and removes "arrive soon" flag (mutually exclusive).
  # Uses update_columns to bypass callbacks and validations, preventing infinite loops
  # and ensuring the flag update doesn't trigger reindexing or other side effects.
  def add_just_arrived_flag_from_variant
    return if skip_auto_flags
    return unless persisted?

    new_flags = flags.dup
    new_flags.delete(FLAGS[:arrive_soon])
    new_flags << FLAGS[:just_arrived] unless new_flags.include?(FLAGS[:just_arrived])

    update_columns(flags: new_flags.uniq) if new_flags != flags
  end

  def formatted_flags
    ProductFlagsFormatterService.call(
      flags: flags,
      free_installment_fee: free_installment_fee
    )
  end

  def reindex
    ProductIndexJob.perform_later(self.id)
  end

  private

  def ensure_default_variant
    return if product_variants.exists?

    product_variants.create!(
      name: 'Default',
      sku: sku,
      slug: slug || Slugify.convert(name, true),
      original_price: 0,
      status: 'active'
    )
  end

  def validate_product_variants
    if product_variants.empty? && !new_record?
      errors.add(:base, 'Product must have at least one variant')
    end

    product_variants.each do |variant|
      unless variant.valid?
        variant.errors.full_messages.each do |msg|
          errors.add(:base, "Variant error: #{msg}")
        end
      end
    end
  end

  def sanitize_product_tags
    return unless product_tags_changed?

    self.product_tags = product_tags.map(&:strip).reject(&:blank?).uniq
  end

  def sanitize_flags
    return unless flags_changed?

    self.flags = flags.reject(&:blank?).uniq if flags
  end

  def flags_inclusion
    if flags.present?
      invalid = flags - FLAGS.values
      errors.add(:flags, "contain invalid value(s): #{invalid.join(', ')}") if invalid.any?
    end
  end

  def handle_post_save_updates
    trigger_collection_update
    normalize_single_variant
    manage_price_flags
    process_external_content_images
  end

  # Manages product flags based on pricing state and lifecycle events.
  #
  # This method automatically sets or removes the 'arrive_soon' and 'just_arrived' flags
  # based on whether all product variants have pricing information available.
  #
  # Timing Logic:
  # - Only runs on creation (when 'id' changes from nil) to avoid repeatedly flagging
  #   existing products that happen to have no pricing as "arrive_soon"
  # - Uses previous_changes.key?('id') to detect when a product is first persisted
  #
  # Flag Mutual Exclusivity:
  # - 'arrive_soon' and 'just_arrived' are mutually exclusive states
  # - If both flags exist, 'arrive_soon' is removed since 'just_arrived' takes priority
  # - Products transition from arrive_soon → just_arrived → normal state
  #
  # Database Update Strategy:
  # - Uses update_columns instead of update to bypass validations and callbacks
  # - Prevents infinite loops since this method itself runs in a callback
  # - Directly updates the database without triggering additional model lifecycle events
  #
  # @return [void]
  # @note Skipped entirely if skip_auto_flags is true or record is not persisted
  def manage_price_flags
    return if skip_auto_flags
    return unless persisted?

    variants = product_variants.reload
    all_variants_priceless = variants.all? { |v| v.original_price.nil? && v.current_price.nil? }

    new_flags = flags.dup

    if all_variants_priceless && previous_changes.key?('id')
      new_flags << FLAGS[:arrive_soon] unless new_flags.include?(FLAGS[:arrive_soon])
      new_flags.delete(FLAGS[:just_arrived])
    end

    if new_flags.include?(FLAGS[:arrive_soon]) && new_flags.include?(FLAGS[:just_arrived])
      new_flags.delete(FLAGS[:arrive_soon])
    end

    # NOTE: Must use update_columns to avoid triggering callbacks again and causing infinite loop.
    update_columns(flags: new_flags.uniq) if new_flags != flags
  end

  def trigger_collection_update
    if status == 'active' || saved_change_to_status&.include?('active')
      CollectionGeneratorJob.perform_later
    end
  end

  def process_external_content_images
    return unless saved_change_to_description? || saved_change_to_short_description?
    return unless id

    ContentImageProcessorJob.perform_later('Product', id)
  end

  def normalize_single_variant
    return unless product_variants.loaded? || product_variants.count == 1
    return if product_variants.count != 1

    variant = product_variants.first
    return if variant.name == 'Default' && variant.sku == sku && variant.slug == (slug || Slugify.convert(name, true))

    variant.update_columns(
      name: 'Default',
      sku: sku,
      slug: slug || Slugify.convert(name, true)
    )
  end

  def revalidate_frontend_cache
    FrontendRevalidateJob.perform_later('Product', id)
  end

  def validate_product_attributes_format
    validate_array_format_attributes(:product_attributes)
  end
end
