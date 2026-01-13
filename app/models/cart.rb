# == Schema Information
#
# Table name: carts
#
#  id               :uuid             not null, primary key
#  cart_type        :enum             default("anonymous")
#  expires_at       :datetime         not null
#  guest_email      :string
#  last_activity_at :datetime         not null
#  metadata         :jsonb
#  status           :enum             default("active")
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  session_id       :string           not null
#  user_id          :bigint
#
# Indexes
#
#  index_carts_on_expires_at            (expires_at)
#  index_carts_on_guest_email           (guest_email)
#  index_carts_on_last_activity_at      (last_activity_at)
#  index_carts_on_session_id            (session_id)
#  index_carts_on_status_and_cart_type  (status,cart_type)
#  index_carts_on_user_id               (user_id) WHERE (user_id IS NOT NULL)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class Cart < ApplicationRecord
  include DynamicJsonbAttributes

  dynamic_jsonb_attribute :metadata

  belongs_to :user, optional: true
  has_many :cart_promotions, dependent: :destroy
  has_many :promotions, through: :cart_promotions
  has_many :cart_items, dependent: :destroy
  has_many :emailed_carts, dependent: :destroy
  has_one :order, dependent: :nullify

  enum :status, {
    active: 'active',
    expired: 'expired',
    checked_out: 'checked_out',
    emailed: 'emailed',
    abandoned: 'abandoned',
    merged: 'merged'
  }, default: 'active', validate: true

  enum :cart_type, {
    authenticated: 'authenticated',
    anonymous: 'anonymous'
  }, default: 'anonymous', validate: true, prefix: true

  validates :session_id, presence: true
  validates :expires_at, presence: true
  validates :last_activity_at, presence: true
  validates :guest_email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true

  scope :expired, -> { where('expires_at < ?', Time.current) }
  scope :active_sessions, -> { where(status: 'active') }
  scope :for_session, ->(session_id) { where(session_id: session_id) }
  scope :for_user, ->(user_id) { where(user_id: user_id) }

  before_validation :set_defaults, on: :create

  attr_reader :calculated_totals

  def expired?
    expires_at < Time.current
  end

  def anonymous?
    user_id.nil?
  end

  def authenticated?
    user_id.present?
  end

  def total_items
    cart_items.sum(:quantity)
  end

  def total_price
    cart_items.sum { |item| item.current_price * item.quantity }
  end

  def calculate_totals!
    @calculated_totals ||= DiscountCalculator.calculate(total_price, promotions, cart: self)
  end

  def subtotal
    calculate_totals! if calculated_totals.nil?

    @calculated_totals[:subtotal]
  end

  def discount_total
    calculate_totals! if calculated_totals.nil?

    @calculated_totals[:discount_amount]
  end

  def bundle_discount
    calculate_totals! if calculated_totals.nil?

    @calculated_totals[:bundle_discount]
  end

  def total
    calculate_totals! if calculated_totals.nil?

    @calculated_totals[:final_total]
  end

  def free_shipping?
    total > 1_000_000
  end

  def touch_activity!
    touch(:last_activity_at)
  end

  def claim_for_user!(user)
    return false if user_id.present?

    update!(
      user_id: user.id,
      cart_type: 'authenticated'
    )
  end

  def auto_apply_bundle_promotions!
    result = AutoApplyBundlePromotionsService.new(self).call
    @calculated_totals = nil
    result.success? ? nil : result.error_code
  end

  private

  def set_defaults
    self.expires_at ||= 3.days.from_now
    self.last_activity_at ||= Time.current
  end
end
