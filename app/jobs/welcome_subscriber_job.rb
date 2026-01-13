class WelcomeSubscriberJob < ApplicationJob
  queue_as :default

  def perform(subscriber)
    SubscriberMailer.welcome_email(subscriber).deliver_now
  end
end
