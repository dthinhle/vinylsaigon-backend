class OrderMailer < ApplicationMailer
  def order_confirmation(order)
    @order = order
    @order_items = order.order_items.includes(:product, :product_variant)
    @shipping_address = order.shipping_address
    @billing_address = order.billing_address

    # Determine recipient email
    recipient_email = order.email.presence || order.user&.email.presence || order.cart&.guest_email.presence

    # If no email can be found from any source, do not attempt to send.
    return unless recipient_email

    mail(
      to: recipient_email,
      subject: "Xác nhận đơn hàng - #{order.order_number}"
    )
  end

  def admin_notification(order)
    @order = order
    @customer_email = order.email.presence || order.user&.email.presence || order.cart&.guest_email.presence || 'N/A'

    admin_email = ENV['ADMIN_EMAIL'] || 'admin@vinylsaigon.vn'

    mail(
      to: admin_email,
      subject: "Đơn hàng mới - #{order.order_number}"
    )
  end

  def payment_success(order)
    @order = order
    recipient_email = order.email.presence || order.user&.email

    return unless recipient_email

    mail(
      to: recipient_email,
      subject: "Thanh toán thành công cho đơn hàng #{order.order_number}"
    )
  end

  def payment_failure(order)
    @order = order
    recipient_email = order.email.presence || order.user&.email

    return unless recipient_email

    mail(
      to: recipient_email,
      subject: "Thanh toán thất bại cho đơn hàng #{order.order_number}"
    )
  end

  def order_canceled(order)
    @order = order
    recipient_email = order.email.presence || order.user&.email

    return unless recipient_email

    mail(
      to: recipient_email,
      subject: "Đơn hàng của bạn đã bị hủy: #{order.order_number}"
    )
  end
end
