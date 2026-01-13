class OrderNotificationJob < ApplicationJob
  queue_as :default

  def perform(order_id)
    order = Order.find_by(id: order_id)

    # Return early if order not found
    unless order
      Rails.logger.warn "OrderNotificationJob: Order with ID #{order_id} not found"
      return
    end

    # Send customer confirmation email
    begin
      OrderMailer.order_confirmation(order).deliver_now
      Rails.logger.info "OrderNotificationJob: Customer confirmation email sent for order #{order.order_number}"
    rescue StandardError => e
      Rails.logger.error "OrderNotificationJob: Failed to send customer confirmation for order #{order.order_number}: #{e.message}"
      # Don't raise exception - continue with admin notification
    end
  end
end
