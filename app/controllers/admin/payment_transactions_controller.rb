# frozen_string_literal: true

class Admin::PaymentTransactionsController < Admin::BaseController
  FILTER_LABELS = {
    'q' => 'Search',
    'status_category' => 'Status',
    'created_after' => 'From Date',
    'created_before' => 'To Date',
    'min_amount' => 'Min Amount',
    'max_amount' => 'Max Amount',
    'order_number' => 'Order Number',
    'merch_txn_ref' => 'Merch Ref',
    'onepay_transaction_id' => 'Txn ID',
    'response_code' => 'Resp Code',
    'payment_status' => 'Pay Status',
    'order_status' => 'Order Status',
    'payment_method' => 'Method',
    'installment_only' => 'Installment',
    'contains_free_installment' => 'Contains Free Installment',
    'fully_free_installment' => 'Fully Free Installment',
    'sort_by' => 'Sort'
  }.freeze

  helper PaymentTransactionsHelper

  def index
    permitted = index_params
    sort_by = permitted[:sort_by].presence || 'created_at_desc'

    scope = PaymentTransaction.includes(:order)
      .search(permitted[:q])
      .by_status_category(permitted[:status_category])
      .by_order_number(permitted[:order_number])
      .by_merch_txn_ref(permitted[:merch_txn_ref])
      .by_onepay_txn_id(permitted[:onepay_transaction_id])
      .by_response_code(permitted[:response_code])
      .by_payment_status(permitted[:payment_status])
      .by_order_status(permitted[:order_status])
      .by_payment_method(permitted[:payment_method])
      .amount_between(permitted[:min_amount], permitted[:max_amount])
      .created_between(permitted[:created_after], permitted[:created_before])
      .contains_free_installment(permitted[:contains_free_installment])
      .fully_free_installment(permitted[:fully_free_installment])

    scope = scope.installment_only if permitted[:installment_only] == 'true'
    scope = scope.apply_sort(sort_by)

    @pagy, @payment_transactions = pagy(scope)

    @filter_params = permitted
    @filter_labels = FILTER_LABELS

    respond_to do |format|
      format.html { render :index }
      format.json { render json: { payment_transactions: @payment_transactions }, status: :ok }
    end
  end

  def show
    @payment_transaction = PaymentTransaction.includes(:order).find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to admin_payment_transactions_path, alert: 'Payment Transaction not found'
  end

  private

  def index_params
    params.permit(
      :q,
      :status_category,
      :created_after,
      :created_before,
      :min_amount,
      :max_amount,
      :order_number,
      :merch_txn_ref,
      :onepay_transaction_id,
      :response_code,
      :payment_status,
      :order_status,
      :payment_method,
      :installment_only,
      :contains_free_installment,
      :fully_free_installment,
      :sort_by,
      :page,
      :per_page
    )
  end
end
