# == Schema Information
#
# Table name: order_items
#
#  id                      :uuid             not null, primary key
#  currency                :string           default("VND"), not null
#  metadata                :jsonb
#  original_unit_price_vnd :bigint           not null
#  product_image_url       :string
#  product_name            :string           not null
#  quantity                :integer          default(1), not null
#  subtotal_vnd            :bigint           not null
#  unit_price_vnd          :bigint           not null
#  warranty_expire_date    :datetime
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  order_id                :uuid             not null
#  product_id              :bigint
#  product_variant_id      :bigint
#
# Indexes
#
#  index_order_items_on_order_id    (order_id)
#  index_order_items_on_product_id  (product_id)
#
# Foreign Keys
#
#  fk_rails_...  (order_id => orders.id)
#  fk_rails_...  (product_id => products.id)
#  fk_rails_...  (product_variant_id => product_variants.id)
#
class OrderItem < ApplicationRecord
  include DynamicJsonbAttributes

  dynamic_jsonb_attribute :metadata

  belongs_to :order
  belongs_to :product, optional: true
  belongs_to :product_variant, optional: true

  validates :product_name, presence: true
  validates :unit_price_vnd, presence: true
  validates :original_unit_price_vnd, presence: true
  validates :subtotal_vnd, presence: true
  validates :quantity, presence: true, numericality: { greater_than: 0 }
  validates :currency, presence: true
end
