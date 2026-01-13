class CartExpirationJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info 'Starting cart expiration cleanup'

    cleanup_expired_cart_items
    expire_old_carts
    cleanup_abandoned_anonymous_carts
    cleanup_expired_email_links

    Rails.logger.info 'Cart expiration cleanup completed'
  end

  private

  def cleanup_expired_cart_items
    expired_items = CartItem.where('expires_at < ?', Time.current)
    expired_count = expired_items.count

    if expired_count > 0
      expired_items.destroy_all
      Rails.logger.info "Removed #{expired_count} expired cart items"
    else
      Rails.logger.info 'No expired cart items to remove'
    end
  end

  def expire_old_carts
    expired_carts = Cart.where('expires_at < ?', Time.current).where(status: 'active')
    expired_count = expired_carts.count

    if expired_count > 0
      expired_carts.update_all(status: 'expired')
      Rails.logger.info "Expired #{expired_count} active carts"
    else
      Rails.logger.info 'No active carts to expire'
    end
  end

  def cleanup_abandoned_anonymous_carts
    abandoned_carts = Cart.anonymous.where('created_at < ?', SESSION_EXPIRES_IN_DAYS.days.ago)
    abandoned_count = abandoned_carts.count

    if abandoned_count > 0
      abandoned_carts.destroy_all
      Rails.logger.info "Cleaned up #{abandoned_count} abandoned anonymous carts"
    else
      Rails.logger.info 'No abandoned anonymous carts to clean up'
    end
  end

  def cleanup_expired_email_links
    expired_emails = EmailedCart.expired
    expired_count = expired_emails.count

    if expired_count > 0
      expired_emails.destroy_all
      Rails.logger.info "Removed #{expired_count} expired email cart links"
    else
      Rails.logger.info 'No expired email cart links to remove'
    end
  end
end
