# frozen_string_literal: true

class OnePayQueryJob < ApplicationJob
  queue_as :default

  # args: order_id, merch_txn_ref, attempt = 1
  def perform(order_id, merch_txn_ref, attempt = 1)
    order = Order.find_by(id: order_id)
    return unless order

    Rails.logger.info "[OnePayQueryJob] perform(order_id=#{order_id}, merch_txn_ref=#{merch_txn_ref}, attempt=#{attempt})"

    # Skip if already paid
    return if order.payment_status_paid?

    begin
      resp = OnePayService.query_dr(order_number: order.order_number, merch_txn_ref: merch_txn_ref)
      Rails.logger.info "[OnePayQueryJob] QueryDR response=#{resp.inspect}"

      if resp.nil?
        Rails.logger.warn "[OnePayQueryJob] QueryDR returned nil (transient) for order=#{order.order_number} attempt=#{attempt}"
        if attempt < 6
          Rails.logger.info "[OnePayQueryJob] Scheduling retry attempt=#{attempt + 1} in 5.minutes"
          OnePayQueryJob.set(wait: 5.minutes).perform_later(order_id, merch_txn_ref, attempt + 1)
        else
          Rails.logger.error "[OnePayQueryJob] Max attempts reached (#{attempt}). Marking order=#{order.order_number} as failed"
          order.update!(payment_status: :failed, status: :failed) if order.payment_status_pending?
        end
        return
      end

      # Enhanced response processing based on 2025 spec
      # Check if transaction exists first
      if resp['vpc_DRExists'] == 'N'
        Rails.logger.warn "[OnePayQueryJob] Transaction does not exist for order=#{order.order_number} merch_txn_ref=#{merch_txn_ref}"
        if attempt < 6
          Rails.logger.info "[OnePayQueryJob] Scheduling retry attempt=#{attempt + 1} in 5.minutes"
          OnePayQueryJob.set(wait: 5.minutes).perform_later(order_id, merch_txn_ref, attempt + 1)
        else
          Rails.logger.error "[OnePayQueryJob] Transaction never found after #{attempt} attempts. Marking order=#{order.order_number} as failed"
          order.update!(payment_status: :failed) if order.payment_status_pending?
        end
        return
      end

      # Process transaction status according to 2025 spec
      response_code = resp['vpc_TxnResponseCode'].to_s
      success = response_code == '0'
      pending = response_code == '300' || response_code == '100'
      explicit_failed = response_code.present? && response_code != '0' && response_code != '300' && response_code != '100'

      if success
        txn_id = resp['vpc_TransactionNo'] || resp['transactionNo'] || resp['onepay_transaction_id']
        amount = (resp['vpc_Amount'] || resp['amount']).to_i / 100

        unless txn_id.present? && PaymentTransaction.exists?(onepay_transaction_id: txn_id)
          PaymentTransaction.create!(
            order: order,
            onepay_transaction_id: txn_id,
            amount: amount,
            status: resp['vpc_TxnResponseCode'] || resp['status'],
            raw_callback: resp
          )
        end

        # If it was an installment payment, record the final details from the callback.
        order.update_installment_details_from_onepay(resp) if order.installment_payment?

        order.update!(payment_status: :paid, status: :paid) unless order.payment_status_paid?
        Rails.logger.info "[OnePayQueryJob] Order #{order.order_number} marked as paid with response code #{response_code}"
        nil
      elsif explicit_failed
        order.update!(payment_status: :failed, status: :failed) if order.payment_status_pending?
        Rails.logger.info "[OnePayQueryJob] Order #{order.order_number} confirmed failed by QueryDR with response code #{response_code}"
        nil
      elsif pending
        # Handle pending states (300, 100) - continue querying
        Rails.logger.info "[OnePayQueryJob] QueryDR indicates pending (#{response_code}) for order=#{order.order_number} attempt=#{attempt}"
        if attempt < 6
          Rails.logger.info "[OnePayQueryJob] Scheduling next attempt=#{attempt + 1} in 5.minutes"
          OnePayQueryJob.set(wait: 5.minutes).perform_later(order_id, merch_txn_ref, attempt + 1)
        else
          Rails.logger.error "[OnePayQueryJob] Max attempts reached (#{attempt}) for pending transaction. Marking order=#{order.order_number} as failed"
          order.update!(payment_status: :failed, status: :failed) if order.payment_status_pending?
        end
        nil
      else
        # Unknown state - treat as pending but log warning
        Rails.logger.warn "[OnePayQueryJob] Unknown response code #{response_code} for order=#{order.order_number} attempt=#{attempt}"
        if attempt < 6
          Rails.logger.info "[OnePayQueryJob] Scheduling next attempt=#{attempt + 1} in 5.minutes"
          OnePayQueryJob.set(wait: 5.minutes).perform_later(order_id, merch_txn_ref, attempt + 1)
        else
          Rails.logger.error "[OnePayQueryJob] Max attempts reached (#{attempt}). Marking order=#{order.order_number} as failed"
          order.update!(payment_status: :failed, status: :failed) if order.payment_status_pending?
        end
        nil
      end
    rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNREFUSED, SocketError => e
      Rails.logger.error "[OnePayQueryJob] Transient network error: #{e.class} #{e.message}\n#{e.backtrace.join("\n")}"
      raise
    rescue StandardError => e
      Rails.logger.error "[OnePayQueryJob] Error: #{e.class} #{e.message}\n#{e.backtrace.join("\n")}"
      # Do not re-raise for non-network errors to avoid unnecessary retries
    end
  end
end
