# frozen_string_literal: true

module Api
  class PaymentsController < Api::BaseController
    # This is the endpoint that OnePay will send a webhook to after a transaction.
    # It handles both server-to-server IPNs and user browser redirects.
    def onepay_callback
      result = ProcessPaymentCallbackService.call(params: params)
      order = result.order

      if result.success?
        # If the request came from a user's browser, redirect them to the frontend.
        # Otherwise, render the plain-text response for Onepay's server.
        if request.headers['User-Agent']&.include?('Mozilla') && order
          frontend_url = ENV.fetch('ONEPAY_FRONTEND_CONFIRMATION_URL', 'http://localhost:3000/thanh-toan/xac-nhan')
          redirect_to "#{frontend_url}?order_number=#{order.order_number}&email=#{order.email}", allow_other_host: true
        else
          render plain: 'responsecode=1&desc=confirm-success', status: :ok
        end
      else
        # The service failed to process the callback. Respond with an error.
        case result.error_code
        when :invalid_hash
          render plain: 'responsecode=0&desc=invalid-hash', status: :ok
        when :order_not_found
          render plain: 'responsecode=0&desc=order-not-found', status: :ok
        else # Includes :processing_error, :payment_failed, etc.
          render plain: 'responsecode=0&desc=processing-error', status: :ok
        end
      end
    end

    # GET /api/payments/installment_options
    # Get available installment options for a given amount
    def installment_options
      amount_vnd = params[:amount].to_i

      if amount_vnd < 3_000_000 # Minimum 3 million VND for installments
        render json: { error: 'Amount must be at least 3,000,000 VND for installment payments' }, status: :unprocessable_entity
        return
      end

      # Convert to OnePay format (multiply by 100)
      amount_onepay = amount_vnd * 100

      options = OnePayService.get_installment_options(amount: amount_onepay)

      if options
        render json: { installment_options: options }
      else
        render json: { error: 'Unable to retrieve installment options' }, status: :service_unavailable
      end
    end
  end
end
