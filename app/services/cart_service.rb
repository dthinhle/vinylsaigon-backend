class CartService
  class << self
    def find_or_create_cart(cart_params)
      session_id = cart_params[:session_id]
      user_id = cart_params[:user_id]

      raise ArgumentError, 'Session ID and user ID cannot be both blank' if session_id.blank? && user_id.blank?

      session_cart = Cart.find_by(session_id: session_id, status: 'active')
      user_cart = Cart.find_by(user_id: user_id, status: 'active') if user_id.present?

      if session_cart && user_cart && session_cart.id != user_cart.id
        session_cart.with_lock do
          if session_cart.status == 'active'
            merge_carts(user_cart, session_cart)
          end
        end
        cart = user_cart
      elsif session_cart && user_id.present? && session_cart.user_id.nil?
        # User logged in with anonymous cart - claim it
        session_cart.claim_for_user!(User.find(user_id))
        cart = session_cart
      elsif user_cart
        # User cart exists
        cart = user_cart
      elsif session_cart
        # Anonymous cart exists
        cart = session_cart
      else
        # No cart exists - create new one
        cart = Cart.create!(
          session_id: session_id,
          user_id: user_id,
          cart_type: user_id ? 'authenticated' : 'anonymous',
          expires_at: 3.days.from_now,
          last_activity_at: Time.current
        )
      end

      cart.touch_activity!
      cart
    end

    def find_cart(cart_params)
      user_id = cart_params[:user_id]
      session_id = cart_params[:session_id]

      if user_id.present?
        Cart.find_by(user_id: user_id, status: 'active')
      else
        Cart.find_by(session_id: session_id, status: 'active')
      end
    end

    def add_item_to_cart(cart_params, product_id, quantity, variant_id = nil)
      cart = find_or_create_cart(cart_params)
      product = Product.find(product_id)
      variant = variant_id ? ProductVariant.find(variant_id) : nil

      if variant && variant.product_id != product.id
        raise ArgumentError, 'Product variant does not belong to the specified product'
      end

      raise ArgumentError, 'Product is not active' unless product.status == 'active'
      raise ArgumentError, 'Product variant is not active' if variant && variant.status != 'active'
      raise ArgumentError, 'Product is not yet available for purchase' if product.flags.include?(Product::FLAGS[:arrive_soon])

      cart_item = cart.cart_items.find_or_initialize_by(
        product_id: product.id,
        product_variant_id: variant&.id
      )

      if cart_item.new_record?
        cart_item.quantity = quantity
      else
        cart_item.quantity += quantity
      end

      cart_item.save!

      auto_apply_error = cart.auto_apply_bundle_promotions!

      { cart_item: cart_item, auto_apply_error: auto_apply_error }
    end

    def add_bundle_to_cart(cart_params, promotion_id)
      cart = find_or_create_cart(cart_params)
      promotion = Promotion.active.bundle.includes(product_bundles: [:product, :product_variant]).find(promotion_id)

      raise ArgumentError, 'Promotion has no bundle items' if promotion.product_bundles.empty?

      promotion.product_bundles.each do |bundle_item|
        product = bundle_item.product
        variant = bundle_item.product_variant

        raise ArgumentError, "Product '#{product.name}' is not active" unless product.status == 'active'
        raise ArgumentError, "Product variant '#{variant&.name}' is not active" if variant && variant.status != 'active'
        raise ArgumentError, "Product '#{product.name}' is not yet available for purchase" if product.flags.include?(Product::FLAGS[:arrive_soon])
      end

      added_items = []

      ActiveRecord::Base.transaction do
        promotion.product_bundles.each do |bundle_item|
          cart_item = cart.cart_items.find_or_initialize_by(
            product_id: bundle_item.product_id,
            product_variant_id: bundle_item.product_variant_id
          )

          if cart_item.new_record?
            cart_item.quantity = bundle_item.quantity
          else
            cart_item.quantity += bundle_item.quantity
          end

          cart_item.save!
          added_items << cart_item
        end
      end

      auto_apply_error = cart.auto_apply_bundle_promotions!

      { cart: cart, added_items: added_items, auto_apply_error: auto_apply_error }
    end

    def update_item_quantity(cart_params, item_id, quantity)
      cart = find_or_create_cart(cart_params)
      cart_item = cart.cart_items.find(item_id)

      unless cart_item.cart_id == cart.id
        raise ArgumentError, 'Cart item does not belong to this cart'
      end

      if quantity <= 0
        cart_item.destroy!
        auto_apply_error = cart.auto_apply_bundle_promotions!
        return { cart_item: nil, auto_apply_error: auto_apply_error }
      end

      cart_item.update!(quantity: quantity)
      auto_apply_error = cart.auto_apply_bundle_promotions!
      { cart_item: cart_item, auto_apply_error: auto_apply_error }
    end

    def remove_item(cart_params, item_id)
      cart = find_or_create_cart(cart_params)
      cart_item = cart.cart_items.find(item_id)

      unless cart_item.cart_id == cart.id
        raise ArgumentError, 'Cart item does not belong to this cart'
      end

      cart_item.destroy!
      auto_apply_error = cart.auto_apply_bundle_promotions!
      { cart: cart, cart_item: nil, auto_apply_error: auto_apply_error }
    end

    def handle_anonymous_cart_on_login(anonymous_cart, user_id)
      raise ArgumentError, 'User ID cannot be nil' if user_id.nil?
      raise ArgumentError, 'Cart must be anonymous' if anonymous_cart.user_id.present?

      user = User.find(user_id)
      user_cart = Cart.find_by(user_id: user_id, status: 'active')

      if user_cart
        merge_carts(user_cart, anonymous_cart)
      else
        anonymous_cart.claim_for_user!(user)
      end
    end

    def email_cart(cart_params, email, create_account_prompt: false)
      cart = find_or_create_cart(cart_params)

      raise ArgumentError, 'Cart is empty' if cart.cart_items.empty?
      raise ArgumentError, 'Invalid email format' unless email.match?(URI::MailTo::EMAIL_REGEXP)

      emailed_cart = cart.emailed_carts.create!(
        email: email,
        recipient_type: cart.authenticated? ? 'authenticated' : 'anonymous'
      )

      CartMailer.with(
        cart: cart,
        emailed_cart: emailed_cart,
        create_account_prompt: create_account_prompt
      ).email_cart.deliver_now

      cart.update!(status: 'emailed')
      emailed_cart
    end

    def get_shared_cart(access_token)
      emailed_cart = EmailedCart.find_by!(access_token: access_token)

      raise ArgumentError, 'Cart link has expired' if emailed_cart.expired?

      emailed_cart.mark_accessed!
      emailed_cart.cart
    end

    # Merges the contents of source_cart into target_cart.
    #
    # This method is public to allow cart merging during user authentication or cart claiming.
    # It should be used with care, as it modifies both carts and their items.
    #
    # Parameters:
    # - target_cart: The cart to merge items into (typically the authenticated user's cart).
    # - source_cart: The cart whose items will be merged (typically an anonymous cart).
    #
    # Behavior:
    # - Raises ArgumentError if attempting to merge the same cart.
    # - If source_cart is already merged, it is destroyed.
    # - For each item in source_cart:
    #   - If the item exists in target_cart, quantities are summed.
    #   - Otherwise, the item is moved to target_cart.
    # - If source_cart has status 'emailed', it is marked as 'merged' (not destroyed).
    #   Otherwise, source_cart is destroyed.
    # - target_cart activity timestamp is updated.
    #
    # Note: This method should not be called directly unless you understand the cart lifecycle.
    def merge_carts(target_cart, source_cart)
      raise ArgumentError, 'Cannot merge the same cart' if target_cart.id == source_cart.id
      return target_cart if source_cart.status == 'merged'

      source_cart.cart_items.find_each do |source_item|
        target_item = target_cart.cart_items.find_by(
          product_id: source_item.product_id,
          product_variant_id: source_item.product_variant_id
        )

        if target_item
          # Merge quantities, keep newer price if different
          target_item.update!(quantity: target_item.quantity + source_item.quantity)
        else
          # Move item to target cart
          source_item.update!(cart: target_cart)
        end
      end

      if source_cart.status == 'emailed'
        source_cart.update!(status: 'merged')
      else
        source_cart.destroy!
      end

      target_cart.touch_activity!
      auto_apply_error = target_cart.auto_apply_bundle_promotions!

      { cart: target_cart, auto_apply_error: auto_apply_error }
    end

    private

    def find_or_create_for_session(session_id, user_id = nil)
      find_or_create_cart({ session_id: session_id, user_id: user_id })
    end
  end
end
