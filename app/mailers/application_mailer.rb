class ApplicationMailer < ActionMailer::Base
  default from: email_address_with_name(STORE_CONFIG[:noreply_email], STORE_CONFIG[:name])
  layout 'mailer'
  helper CurrencyHelper
end
