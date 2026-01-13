class SessionTrackingService
  class << self
    def create_session
      session_id = SecureRandom.urlsafe_base64(32)

      Cart.create!(session_id: session_id, status: 'active', expires_at: 30.days.from_now)
    end

    def validate_session(session_id)
      return false if session_id.blank?

      Cart.exists?(session_id: session_id, status: 'active')
    end

    def cleanup_expired_sessions
      expired_carts = Cart.where('expires_at < ? AND status = ?', Time.current, 'active')
      expired_carts.update_all(status: 'expired')

      Cart.joins(:cart_items)
          .where('cart_items.expires_at < ?', Time.current)
          .find_each { |cart| cart.cart_items.expired.destroy_all }

      Cart.where('user_id IS NULL AND created_at < ?', SESSION_EXPIRES_IN_DAYS.days.ago).destroy_all

      EmailedCart.expired.destroy_all
    end
  end
end
