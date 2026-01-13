class CartMailer < ApplicationMailer
  helper MailerHelper

  def email_cart
    @cart = params[:cart]
    @emailed_cart = params[:emailed_cart]
    @create_account_prompt = params[:create_account_prompt]
    @share_url = @emailed_cart.share_url

    mail(
      to: @emailed_cart.email,
      subject: "Giỏ hàng của bạn - #{@cart.total_items} sản phẩm"
    )
  end
end
