# == Schema Information
#
# Table name: payment_transactions
#
#  id                    :uuid             not null, primary key
#  amount                :decimal(, )
#  merch_txn_ref         :string
#  raw_callback          :jsonb
#  status                :string
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  onepay_transaction_id :string
#  order_id              :uuid             not null
#
# Indexes
#
#  index_payment_transactions_on_merch_txn_ref          (merch_txn_ref)
#  index_payment_transactions_on_onepay_transaction_id  (onepay_transaction_id) UNIQUE
#  index_payment_transactions_on_order_id               (order_id)
#
# Foreign Keys
#
#  fk_rails_...  (order_id => orders.id)
#
class PaymentTransaction < ApplicationRecord
  belongs_to :order

  # === Scopes ===
  scope :search, ->(q) {
    return all if q.blank? || q.strip.length < 2
    pattern = "%#{q.strip}%"
    joins(:order).where(
      arel_table[:onepay_transaction_id].matches(pattern)
        .or(arel_table[:merch_txn_ref].matches(pattern))
        .or(Order.arel_table[:order_number].matches(pattern))
    )
  }

  scope :by_status_category, ->(cat) {
    case cat
    when 'success' then where(status: '0')
    when 'pending' then where(status: %w[300 100])
    when 'failed' then where.not(status: ['0', '300', '100']).where.not(status: nil)
    when 'unknown' then where(status: nil)
    else all
    end
  }

  scope :by_response_code, ->(code) { code.present? ? where(status: code) : all }
  scope :by_order_number, ->(num) { num.present? ? joins(:order).where('orders.order_number ILIKE ?', "%#{num}%") : all }
  scope :by_merch_txn_ref, ->(ref) { ref.present? ? where('payment_transactions.merch_txn_ref ILIKE ?', "%#{ref}%") : all }
  scope :by_onepay_txn_id, ->(id) { id.present? ? where(onepay_transaction_id: id) : all }
  scope :by_payment_status, ->(ps) { ps.present? ? joins(:order).where(orders: { payment_status: ps }) : all }
  scope :by_order_status, ->(os) { os.present? ? joins(:order).where(orders: { status: os }) : all }
  # payment_method is stored inside orders.metadata (jsonb) under 'payment_method'
  scope :by_payment_method, ->(pm) {
    return all unless pm.present?
    joins(:order).where("orders.metadata ->> 'payment_method' = ?", pm)
  }
  scope :installment_only, -> { joins(:order).where("orders.metadata ->> 'payment_method' = 'installment'") }
  scope :contains_free_installment, ->(value) {
    return all unless %w[true false].include?(value.to_s)
    if value.to_s == 'true'
      joins(order: { order_items: :product }).where(products: { free_installment_fee: true }).distinct
    else
      where.not(
        'EXISTS (SELECT 1 FROM orders o JOIN order_items oi ON oi.order_id = o.id JOIN products p ON p.id = oi.product_id WHERE o.id = payment_transactions.order_id AND p.free_installment_fee = TRUE)'
      )
    end
  }
  scope :fully_free_installment, ->(value) {
    return all unless %w[true false].include?(value.to_s)
    if value.to_s == 'true'
      where(
        'EXISTS (SELECT 1 FROM orders o JOIN order_items oi ON oi.order_id = o.id WHERE o.id = payment_transactions.order_id) AND NOT EXISTS (SELECT 1 FROM orders o2 JOIN order_items oi2 ON oi2.order_id = o2.id JOIN products p2 ON p2.id = oi2.product_id WHERE o2.id = payment_transactions.order_id AND p2.free_installment_fee = FALSE)'
      )
    else
      where(
        'EXISTS (SELECT 1 FROM orders o JOIN order_items oi ON oi.order_id = o.id JOIN products p ON p.id = oi.product_id WHERE o.id = payment_transactions.order_id AND p.free_installment_fee = FALSE)'
      )
    end
  }
  scope :amount_between, ->(min, max) {
    scope = all
    scope = scope.where('amount >= ?', min) if min.present?
    scope = scope.where('amount <= ?', max) if max.present? && (min.blank? || max.to_d >= min.to_d)
    scope
  }
  scope :created_between, ->(from, to) {
    scope = all
    scope = scope.where('payment_transactions.created_at >= ?', from.to_date.beginning_of_day) if from.present?
    scope = scope.where('payment_transactions.created_at <= ?', to.to_date.end_of_day) if to.present? && (from.blank? || to.to_date >= from.to_date)
    scope
  }

  def self.apply_sort(sort_by)
    return order(created_at: :desc) if sort_by.blank?
    field, direction = sort_by.to_s.rpartition('_').values_at(0, 2)
    dir = %w[asc desc].include?(direction) ? direction : 'desc'
    case field
    when 'created_at' then order(created_at: dir)
    when 'amount' then order(amount: dir, created_at: :desc)
    when 'response_code' then order(status: dir, created_at: :desc)
    when 'order_number' then joins(:order).order("orders.order_number #{dir}")
    when 'txn_id' then order(onepay_transaction_id: dir, created_at: :desc)
    else order(created_at: :desc)
    end
  end

  # Delegate Free Installment Fee flag helpers to order
  delegate :has_free_installment_product?, :fully_free_installment_order?, to: :order, allow_nil: true
end
