# frozen_string_literal: true

module PaymentTransactionsHelper
  def map_code_to_category(code)
    case code
    when '0' then :success
    when '300', '100' then :pending
    when nil then :unknown
    else :failed
    end
  end

  def payment_txn_status_badge(code)
    category = map_code_to_category(code)
    css = {
      success: 'bg-green-100 text-green-700',
      pending: 'bg-yellow-100 text-yellow-700',
      failed: 'bg-red-100 text-red-700',
      unknown: 'bg-gray-100 text-gray-700'
    }[category]
    label = {
      success: 'Success',
      pending: 'Pending',
      failed: 'Failed',
      unknown: 'Unknown'
    }[category]
    content_tag(:span, label, class: "inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium #{css}")
  end

 # === Sorting Helpers ===
 # Map human headers -> sort field keys (aligns with PaymentTransaction.apply_sort cases)
 def payment_transaction_sortable_columns
    {
      'Txn ID' => 'txn_id', # custom (onepay_transaction_id)
      'Order' => 'order_number',
      'Amount' => 'amount',
      'Resp Code' => 'response_code',
      'Created' => 'created_at'
    }
  end

  # Full header list in display order
  def payment_transaction_table_headers
    [
      'Txn ID',
      'Order',
      'Amount',
      'Resp Code',
      'Order Pay Status',
      'Method',
      'Created',
      'Actions',
    ]
  end

 # Render <th> cells with clickable sort links & visual indicators ▲/▼
 def render_payment_transaction_table_headers(params)
    current_sort, current_direction = params[:sort_by].present? ? params[:sort_by].rpartition('_').values_at(0, 2) : [nil, nil]
    current_direction ||= 'desc'
    sortable = payment_transaction_sortable_columns

    payment_transaction_table_headers.map do |header|
      if sortable[header]
        col = sortable[header]
        dir = (current_sort == col && current_direction == 'asc') ? 'desc' : 'asc'
        indicator = current_sort == col ? (current_direction == 'asc' ? ' ▲' : ' ▼') : ''
        content_tag :th, class: 'px-4 py-3 text-left font-medium text-gray-700 text-sm' do
          link_to(
            (header + indicator).html_safe,
            url_for(request.query_parameters.merge(sort_by: [col, dir].join('_'), page: nil)),
            class: "hover:underline #{current_sort == col ? 'text-gray-950' : ''}"
          )
        end
      else
        align = header == 'Actions' ? 'text-right' : 'text-left'
        content_tag :th, header, class: "px-4 py-3 #{align} font-medium text-gray-700 text-sm"
      end
    end.join.html_safe
  end

  # Methods from PaymentTransactionPresenter
  def payment_transaction_category(transaction)
    case transaction.status
    when '0' then :success
    when '300', '100' then :pending
    when nil then :unknown
    else :failed
    end
  end

 def payment_transaction_category_label(transaction)
    {
      success: 'Success',
      pending: 'Pending',
      failed: 'Failed',
      unknown: 'Unknown'
    }[payment_transaction_category(transaction)]
  end

  def payment_transaction_mismatch_messages(transaction)
    order = transaction.order
    msgs = []
    category = payment_transaction_category(transaction)
    if category == :success && order.payment_status != 'paid'
      msgs << 'Transaction succeeded but order not marked paid.'
    end
    if category == :failed && order.payment_status == 'paid'
      msgs << 'Latest transaction failed while order shows paid.'
    end
    msgs
  end

 def payment_transaction_installment?(transaction)
    order = transaction.order
    order.respond_to?(:installment_payment?) && order.installment_payment?
  end

  def payment_transaction_installment_details(transaction)
    order = transaction.order
    return {} unless payment_transaction_installment?(transaction)
    {
      months: order.installment_months,
      fee_amount: order.installment_fee_amount,
      bank: order.installment_bank
    }.compact
  end

  def payment_transaction_formatted_amount(transaction)
    amount = transaction.amount.to_i
    format_vnd_currency(amount) if defined?(format_vnd_currency)
  end

  def payment_transaction_raw_callback_pretty(transaction)
    return '{}' unless transaction.raw_callback.present?
    JSON.pretty_generate(transaction.raw_callback)
  rescue
    transaction.raw_callback.to_json
  end
end
