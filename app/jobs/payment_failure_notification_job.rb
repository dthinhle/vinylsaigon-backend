# frozen_string_literal: true

# This job is responsible for sending a payment failure notification email to the customer.
# It is enqueued after a payment has failed.
class PaymentFailureNotificationJob < ApplicationJob
  queue_as :default

  def perform(order_id)
    order = Order.find_by(id: order_id)
    return unless order

    OrderMailer.payment_failure(order).deliver_now
    Rails.logger.info "[PaymentFailureNotificationJob] Sent payment failure email for order #{order.order_number}"
  rescue StandardError => e
    Rails.logger.error "[PaymentFailureNotificationJob] Failed to send email for order #{order_id}: #{e.message}"
  end
end
