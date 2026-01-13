class AdminOrderNotificationJob < ApplicationJob
  queue_as :default

  def perform(order_id)
    order = Order.find_by(id: order_id)
    return unless order

    notifiable_admins = Admin.where(order_notify: true)

    notifiable_admins.each do |admin|
      begin
        AdminMailer.new_order_notification(admin, order).deliver_now
        Rails.logger.info "[AdminOrderNotificationJob] Sent notification to admin #{admin.email} for order #{order.order_number}"
      rescue StandardError => e
        Rails.logger.error "[AdminOrderNotificationJob] Failed to send notification to admin #{admin.email} for order #{order.order_number}: #{e.message}"
      end
    end
  end
end
