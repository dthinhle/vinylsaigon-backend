class UserMailer < Devise::Mailer
  layout 'mailer'
  default template_path: 'devise/mailer' # to make sure that your mailer uses the devise views
  default from: email_address_with_name('noreply@3kshop.vn', '3K Shop')

  def reset_password_instructions(record, token, opts = {})
    @token = token
    @resource = record
    @opts = opts

    # Store the raw token for use in email templates
    @raw_token = token

    mail(to: @resource.email, subject: 'Hướng dẫn đặt lại mật khẩu')
  end
end
