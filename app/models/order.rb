# == Schema Information
#
# Table name: orders
#
#  id                  :uuid             not null, primary key
#  currency            :string           default("VND"), not null
#  discount_vnd        :bigint           default(0), not null
#  email               :string
#  metadata            :jsonb
#  name                :string
#  order_number        :string           not null
#  payment_method      :string
#  payment_status      :string           default("pending"), not null
#  phone_number        :string
#  shipping_method     :enum             default("ship_to_address"), not null
#  shipping_vnd        :bigint           default(0), not null
#  status              :enum             default("awaiting_payment"), not null
#  subtotal_vnd        :bigint           default(0), not null
#  tax_vnd             :bigint           default(0), not null
#  total_vnd           :bigint           default(0), not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  billing_address_id  :bigint
#  cart_id             :uuid
#  shipping_address_id :bigint
#  store_address_id    :bigint
#  user_id             :bigint
#
# Indexes
#
#  index_orders_on_cart_id         (cart_id)
#  index_orders_on_email           (email)
#  index_orders_on_order_number    (order_number) UNIQUE
#  index_orders_on_payment_status  (payment_status)
#  index_orders_on_status          (status)
#  index_orders_on_user_id         (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (billing_address_id => addresses.id)
#  fk_rails_...  (cart_id => carts.id)
#  fk_rails_...  (shipping_address_id => addresses.id)
#  fk_rails_...  (user_id => users.id)
#
class Order < ApplicationRecord
  include DynamicJsonbAttributes

  dynamic_jsonb_attribute :metadata

  ORDER_PAYMENT_METHODS = {
    ONEPAY: 'onepay',
    COD: 'cod',
    BANK_TRANSFER: 'bank_transfer',
    INSTALLMENT: 'installment'
  }.freeze

  # Skip the strict metadata validation for Order model
  skip_callback :validate, :before, :validate_dynamic_jsonb_attributes

  belongs_to :user, optional: true
  belongs_to :cart, optional: true
  has_many :order_items, dependent: :destroy
  belongs_to :billing_address, class_name: 'Address', optional: true
  belongs_to :shipping_address, class_name: 'Address', optional: true
  has_many :promotion_usages, as: :redeemable, dependent: :destroy
  has_many :promotions, through: :promotion_usages

  enum :status, {
    awaiting_payment: 'awaiting_payment',
    paid: 'paid',
    canceled: 'canceled',
    confirmed: 'confirmed',
    fulfilled: 'fulfilled',
    refunded: 'refunded',
    failed: 'failed'
  }, default: 'awaiting_payment', validate: true, prefix: true

  enum :shipping_method, {
    ship_to_address: 'ship_to_address',
    pick_up_at_store: 'pick_up_at_store'
  }, default: 'ship_to_address', validate: true, prefix: true

  # Tracks the payment status of the order, separate from the fulfillment status.
  enum :payment_status, {
    pending: 'pending',
    paid: 'paid',
    failed: 'failed'
  }, default: 'pending', validate: true, prefix: true

  validates :order_number, presence: true, uniqueness: true
  validates :total_vnd, presence: true
  validates :currency, presence: true

  scope :recent, -> { order(created_at: :desc) }
  scope :by_status, ->(status) { where(status: status) if status.present? }
  scope :for_user, ->(user_id) { where(user_id: user_id) if user_id.present? }

  # Recalculates and updates the discount and total based on the current state.
  # This should be called after associating or dissociating promotions.
  def recalculate_totals!
    self.subtotal_vnd = order_items.sum(&:subtotal_vnd)

    result = DiscountCalculator.calculate(subtotal_vnd, promotions, cart:)
    self.discount_vnd = result[:discount_amount]
    self.total_vnd = [(result[:final_total] + shipping_vnd + tax_vnd), 0].max

    save!
  end

  # Installment payment support
  def installment_payment?
    metadata['payment_method'] == 'installment'
  end

  def installment_months
    metadata['installment_months']&.to_i
  end

  def installment_fee_amount
    metadata['installment_fee_amount']&.to_i
  end

  def installment_bank
    metadata['installment_bank']
  end

  def set_installment_info(months:, fee_amount:, bank: nil)
    self.metadata = metadata.merge({
      'payment_method' => 'installment',
      'installment_months' => months,
      'installment_fee_amount' => fee_amount,
      'installment_bank' => bank
    })
  end

  def update_installment_details_from_onepay(onepay_params)
    return unless installment_payment?

    set_installment_info(
      months: onepay_params['vpc_ItaTime'],
      fee_amount: onepay_params['vpc_ItaFeeAmount'],
      bank: onepay_params['vpc_ItaBank']
    )
    save!
  end

  # Check if order contains any products with free_installment_fee flag
  def has_free_installment_product?
    order_items.joins(:product).where(products: { free_installment_fee: true }).exists?
  end

  # Check if ALL products in order have free_installment_fee flag (eligible for manual refund)
  def fully_free_installment_order?
    return false if order_items.empty?

    !order_items.joins(:product).where(products: { free_installment_fee: false }).exists?
  end

  private

  after_commit :enqueue_cancellation_notification, on: :update
  after_save :update_warranty_expiration_dates, if: :saved_change_to_status?

  def enqueue_cancellation_notification
    if saved_change_to_status? && status_canceled?
      OrderCanceledNotificationJob.perform_later(id)
    end
  end

  def update_warranty_expiration_dates
    return unless status_fulfilled?

    order_items.includes(:product).each do |item|
      next unless item.product&.warranty_months.present?

      item.update_columns(warranty_expire_date: Time.current + item.product.warranty_months.months)
    end
  end
end
