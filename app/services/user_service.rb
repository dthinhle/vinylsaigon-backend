# frozen_string_literal: true

class UserService
  def initialize(user)
    @user = user
  end

  def update(user_params)
    @user_params = user_params
    @errors = []

    ActiveRecord::Base.transaction do
      update_user_profile
      handle_newsletter_subscription

      if @errors.any?
        raise ActiveRecord::Rollback
      end
    end

    if @errors.any?
      failure_result(@errors.join(', '))
    else
      success_result
    end
  end

  private

  attr_reader :user, :user_params

  def update_user_profile
    # Update user attributes excluding newsletter subscription
    unless user.update(user_params.except(:subscribe_newsletter))
      @errors << user.errors.full_messages.to_sentence
      Rails.logger.error("Failed to update user profile: #{user.errors.full_messages}")
    end
  end

  def handle_newsletter_subscription
    return unless user_params.key?(:subscribe_newsletter)

    if user_params[:subscribe_newsletter] && !user.subscriber
      create_subscriber
    elsif !user_params[:subscribe_newsletter] && user.subscriber
      remove_subscriber
    end
  end

  def create_subscriber
    subscriber = Subscriber.new(email: user.email)

    unless subscriber.save
      @errors << "Failed to subscribe to newsletter: #{subscriber.errors.full_messages.to_sentence}"
      Rails.logger.error("Failed to create subscriber for user #{user.id}: #{subscriber.errors.full_messages}")
    end
  end

  def remove_subscriber
    unless user.subscriber.destroy
      @errors << "Failed to unsubscribe from newsletter: #{user.subscriber.errors.full_messages.to_sentence}"
      Rails.logger.error("Failed to remove subscriber for user #{user.id}: #{user.subscriber.errors.full_messages}")
    end
  end

  def success_result
    {
      success: true,
      user: user,
      message: 'Profile updated successfully'
    }
  end

  def failure_result(message)
    {
      success: false,
      user: user,
      message: message,
      errors: user.errors.full_messages
    }
  end
end
