# frozen_string_literal: true

class PaymentTransactionPresenter
  def initialize(transaction)
    @txn = transaction
  end

  attr_reader :txn

  delegate :order, :amount, :status, :merch_txn_ref, :onepay_transaction_id, :raw_callback, :created_at, to: :txn

  def installment?
    order && order.respond_to?(:installment_payment?) && order.installment_payment?
  end

  def category
    case status
    when '0' then :success
    when '300', '100' then :pending
    when nil then :unknown
    else :failed
    end
  end

  def mismatch_messages
    msgs = []
    if category == :success && order && order.payment_status != 'paid'
      msgs << 'Transaction succeeded but order not marked paid.'
    end
    if category == :failed && order && order.payment_status == 'paid'
      msgs << 'Latest transaction failed while order shows paid.'
    end
    msgs
  end

  def installment_details
    return {} unless installment?
    {
      months: order.installment_months,
      fee_amount: order.installment_fee_amount,
      bank: order.installment_bank
    }.compact
  end

  def formatted_amount(view = nil)
    if view && view.respond_to?(:format_vnd_currency)
      view.format_vnd_currency(amount.to_i)
    else
      amount.to_i.to_s
    end
  end

  def raw_callback_pretty
    return '{}' unless raw_callback.present?
    JSON.pretty_generate(raw_callback)
  rescue
    raw_callback.to_json
  end
end
