# == Schema Information
#
# Table name: cart_items
#
#  id                 :uuid             not null, primary key
#  added_at           :datetime         not null
#  currency           :string           default("USD"), not null
#  current_price      :decimal(10, 2)   not null
#  expires_at         :datetime         not null
#  original_price     :decimal(10, 2)   not null
#  product_image_url  :string
#  product_name       :string           not null
#  quantity           :integer          default(1), not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  cart_id            :uuid             not null
#  product_id         :bigint           not null
#  product_variant_id :bigint
#
# Indexes
#
#  index_cart_items_on_cart_id             (cart_id)
#  index_cart_items_on_expires_at          (expires_at)
#  index_cart_items_on_product_id          (product_id)
#  index_cart_items_on_product_variant_id  (product_variant_id)
#  index_cart_items_uniqueness             (cart_id,product_id,product_variant_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (cart_id => carts.id)
#  fk_rails_...  (product_id => products.id)
#  fk_rails_...  (product_variant_id => product_variants.id)
#
class CartItem < ApplicationRecord
  belongs_to :cart
  belongs_to :product
  belongs_to :product_variant, optional: true

  validates :quantity, presence: true, numericality: { greater_than: 0 }
  validates :current_price, presence: true, numericality: { greater_than: 0 }
  validates :original_price, presence: true, numericality: { greater_than: 0 }
  validates :product_name, presence: true
  validates :currency, presence: true
  validates :added_at, presence: true
  validates :expires_at, presence: true

  scope :expired, -> { where('expires_at < ?', Time.current) }
  scope :active, -> { where('expires_at >= ?', Time.current) }

  before_validation :set_defaults, on: :create
  before_validation :freeze_product_info, on: :create

  def expired?
    expires_at < Time.current
  end

  def line_total
    current_price * quantity
  end

  def price_changed?
    return false unless product.present?

    effective_price = product_variant&.original_price || 0
    effective_price != current_price
  end

  def current_market_price
    return 0 unless product.present?

    product_variant&.original_price || 0
  end

  def savings
    return 0 if current_market_price <= current_price

    (current_market_price - current_price) * quantity
  end

  private

  def set_defaults
    self.added_at ||= Time.current
    self.expires_at ||= 3.days.from_now
    self.currency ||= 'USD'
  end

  def freeze_product_info
    return unless product.present?

    if product_variant.present?
      self.current_price ||= product_variant.current_price || product_variant.original_price
      self.original_price ||= product_variant.original_price
    else
      default_variant = product.product_variants.first
      if default_variant
        self.current_price ||= default_variant.current_price || default_variant.original_price
        self.original_price ||= default_variant.original_price
      else
        self.current_price ||= 0
        self.original_price ||= 0
      end
    end

    self.product_name ||= product.name

    variant = if product_variant.present?
      product_variant
    else
      product.product_variants.first
    end

    self.product_image_url ||= ImagePathService.new(variant.images.first).path if variant
  end
end
