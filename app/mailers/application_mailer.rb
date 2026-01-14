class ApplicationMailer < ActionMailer::Base
  default from: email_address_with_name('noreply@vinylsaigon.vn', 'Vinyl Saigon')
  layout 'mailer'
  helper CurrencyHelper
end
