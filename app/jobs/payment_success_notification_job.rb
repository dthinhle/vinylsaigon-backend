# frozen_string_literal: true

# This job is responsible for sending a payment success confirmation email to the customer.
# It is enqueued after a payment has been successfully processed.
class PaymentSuccessNotificationJob < ApplicationJob
  queue_as :default

  def perform(order_id)
    order = Order.find_by(id: order_id)
    return unless order

    OrderMailer.payment_success(order).deliver_now
    Rails.logger.info "[PaymentSuccessNotificationJob] Sent payment success email for order #{order.order_number}"
  rescue StandardError => e
    Rails.logger.error "[PaymentSuccessNotificationJob] Failed to send email for order #{order_id}: #{e.message}"
  end
end
