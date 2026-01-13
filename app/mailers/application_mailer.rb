class ApplicationMailer < ActionMailer::Base
  default from: email_address_with_name('noreply@3kshop.vn', '3K Shop')
  layout 'mailer'
  helper CurrencyHelper
end
