class SubscriberMailer < ApplicationMailer
  def welcome_email(subscriber)
    @subscriber = subscriber
    mail(to: @subscriber.email, subject: "Chào mừng tới tin tức của #{STORE_CONFIG[:name]}!")
  end
end
