# frozen_string_literal: true

# This job is responsible for sending an order cancellation notification email to the customer.
class OrderCanceledNotificationJob < ApplicationJob
  queue_as :default

  def perform(order_id)
    order = Order.find_by(id: order_id)
    return unless order

    notifiable_admins = Admin.where(order_notify: true)

    notifiable_admins.each do |admin|
      begin
        AdminMailer.order_canceled_notification(admin, order).deliver_now
        Rails.logger.info "[AdminOrderNotificationJob] Sent notification to admin #{admin.email} for order #{order.order_number}"
      rescue StandardError => e
        Rails.logger.error "[AdminOrderNotificationJob] Failed to send notification to admin #{admin.email} for order #{order.order_number}: #{e.message}"
      end
    end
  end
end
