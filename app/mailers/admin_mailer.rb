class AdminMailer < ApplicationMailer
  def welcome_email(admin, reset_password_token)
    @admin = admin
    @reset_password_url = edit_admin_password_url(reset_password_token: reset_password_token)

    mail(
      to: @admin.email,
      subject: 'Welcome to Vinyl Saigon Admin - Set Your Password'
    )
  end

  def new_order_notification(admin, order)
    @admin = admin
    @order = order
    @order_items = order.order_items.includes(:product, :product_variant)

    mail(
      to: @admin.email,
      subject: "Đơn hàng mới - #{@order.order_number}"
    )
  end

  def order_canceled_notification(admin, order)
    @admin = admin
    @order = order

    mail(
      to: @admin.email,
      subject: "Đơn hàng bị huỷ - #{@order.order_number}"
    )
  end
end
