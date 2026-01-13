# frozen_string_literal: true

# Service to encapsulate the entire business logic of processing a OnePay payment callback.
# This includes hash verification, idempotency checks, order status validation, and final state updates.
class ProcessPaymentCallbackService
  # A lightweight struct to return a clear and consistent result to the controller.
  Result = Struct.new(:success?, :order, :error_code, :already_processed?)

  def self.call(**args)
    new(**args).call
  end

  def initialize(params:)
    @params = params.to_unsafe_h
    @order = nil
  end

  def call
    # 1. Verify the callback hash. If it fails, attempt a QueryDR lookup as a fallback.
    return query_dr_fallback unless OnePayService.verify_callback(@params)

    # 2. Find the associated order.
    @order = Order.find_by(order_number: @params['vpc_MerchTxnRef'].split('--').first)
    return Result.new(false, nil, :order_not_found) unless @order

    # 3. IDEMPOTENCY CHECK: See if this transaction has already been successfully recorded.
    onepay_txn_id = @params['vpc_TransactionNo']
    if onepay_txn_id.present? && PaymentTransaction.exists?(onepay_transaction_id: onepay_txn_id)
      Rails.logger.info "[ProcessPaymentCallbackService] Already processed transaction #{onepay_txn_id} for order #{@order.order_number}"
      return Result.new(true, @order, nil, true) # Success, but already handled.
    end

    # 4. Record the transaction for auditing. This is created even if the order is in a final state.
    PaymentTransaction.create!(
      order: @order,
      onepay_transaction_id: onepay_txn_id,
      merch_txn_ref: @params['vpc_MerchTxnRef'],
      amount: @params['vpc_Amount'].to_i / 100,
      status: @params['vpc_TxnResponseCode'],
      raw_callback: @params
    )

    # 5. VALIDATION: Only update the order if it's still awaiting payment or has failed.
    unless @order.payment_status_pending? || @order.payment_status_failed?
      Rails.logger.warn "[ProcessPaymentCallbackService] Received callback for order #{@order.order_number} which is already in a final state (#{@order.payment_status}). Ignoring status update."
      return Result.new(true, @order, nil, true) # Success, but order was already in a final state.
    end

    # 6. Update the order's payment status based on the response code.
    update_order_status

    Result.new(true, @order, nil, false)
  rescue ActiveRecord::RecordNotUnique
    # This handles the race condition where two callbacks arrive at the same time.
    # The database index prevents a duplicate record, and we can safely treat this as a success.
    Rails.logger.warn "[ProcessPaymentCallbackService] Race condition averted: PaymentTransaction for order #{@order.order_number} already exists."
    Result.new(true, @order, nil, true)
  rescue StandardError => e
    Rails.logger.error "[ProcessPaymentCallbackService] Error processing callback for order #{@order&.order_number}: #{e.message}"
    Result.new(false, @order, :processing_error)
  end

  private

  def update_order_status
    response_code = @params['vpc_TxnResponseCode'].to_s

    if response_code == '0' # '0' means success
      @order.update!(payment_status: :paid, status: :paid)
      PaymentSuccessNotificationJob.perform_later(@order.id)
      AdminOrderNotificationJob.perform_later(@order.id)
      Rails.logger.info "[ProcessPaymentCallbackService] Enqueued admin notification for order #{@order.order_number}"

      # If it was an installment payment, record the final details from the callback.
      @order.update_installment_details_from_onepay(@params) if @order.installment_payment?
    else
      # Any other non-zero code is a failure.
      @order.update!(payment_status: :failed, status: :failed)
      PaymentFailureNotificationJob.perform_later(@order.id)
      Rails.logger.info "[ProcessPaymentCallbackService] Order #{@order.order_number} failed with code: #{response_code} (#{@params['vpc_Message']})"
    end
  end

  # Fallback mechanism for when the initial callback hash is invalid.
  def query_dr_fallback
    merch_txn_ref = @params['vpc_MerchTxnRef']
    return Result.new(false, nil, :invalid_hash) unless merch_txn_ref.present?

    @order = Order.find_by(order_number: merch_txn_ref.split('--').first)
    return Result.new(false, nil, :order_not_found) unless @order

    # Only attempt QueryDR if the order is still pending.
    return Result.new(true, @order, nil, true) unless @order.payment_status_pending?

    begin
      # Determine if it's an installment query by checking the merchant ID from the callback
      is_installment = @params['vpc_Merchant'] == ENV.fetch('ONEPAY_INSTALLMENT_MERCHANT_ID')

      resp = OnePayService.query_dr(order_number: @order.order_number, merch_txn_ref: merch_txn_ref, is_installment: is_installment)
      Rails.logger.info "[ProcessPaymentCallbackService] OnePay QueryDR response=#{resp.inspect}"

      # Check for a successful transaction status from the QueryDR response.
      if resp && (resp['vpc_TxnResponseCode'] == '0' || resp['txn_status'] == '0')
        # IDEMPOTENCY for QueryDR
        txn_id = resp['vpc_TransactionNo'] || resp['transactionNo']
        unless txn_id.present? && PaymentTransaction.exists?(onepay_transaction_id: txn_id)
          PaymentTransaction.create!(order: @order, onepay_transaction_id: txn_id, amount: (resp['vpc_Amount'] || resp['amount']).to_i / 100, status: resp['vpc_TxnResponseCode'], raw_callback: resp)
        end
        unless @order.payment_status_paid?
          @order.update!(payment_status: :paid, status: :paid)
          AdminOrderNotificationJob.perform_later(@order.id)
          Rails.logger.info "[ProcessPaymentCallbackService] Enqueued admin notification for order #{@order.order_number} via QueryDR"
        end
        Result.new(true, @order, nil, false)
      else
        @order.update!(payment_status: :failed, status: :failed) if @order.payment_status_pending?
        Result.new(false, @order, :payment_failed)
      end
    rescue StandardError => e
      Rails.logger.error "[ProcessPaymentCallbackService] QueryDR lookup failed: #{e.class} #{e.message}"
      Result.new(false, @order, :processing_error)
    end
  end
end
