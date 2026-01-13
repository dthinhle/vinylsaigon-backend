# frozen_string_literal: true

# OrderCreatorService converts a shopping cart into an order with complete snapshotting,
# promotion application, and transaction safety. This service handles the entire checkout
# flow including address management, price calculations, and cart status updates.
#
# Usage:
#   OrderCreatorService.call(
#     cart: cart_instance,
#     user: current_user,
#     shipping_address_params: { address: '...', city: '...' },
#     apply_promotions: true,
#     idempotency_key: 'unique-key'
#   )
#
class OrderCreatorService
  # Custom domain errors for better error handling
  class AlreadyCheckedOutError < StandardError; end
  class InvalidAddressError < StandardError; end
  class EmptyCartError < StandardError; end
  class InvalidPromotionCombinationError < StandardError; end

  # Public API: create an order from a cart
  # @param cart [Cart] required - Cart object with items
  # @param user [User] optional - User object for authenticated checkout
  # @param shipping_address_params [Hash] optional - Hash of address attributes
  # @param billing_address_params [Hash] optional - Hash of address attributes
  # @param shipping_address_id [Integer] optional - ID of existing address
  # @param billing_address_id [Integer] optional - ID of existing address
  # @param currency [String] optional - Currency code (defaults to 'USD')
  # @param apply_promotions [Boolean] optional - Whether to apply promotions
  # @param idempotency_key [String] optional - Key for idempotent requests
  # @return [Order] The created order
  def self.call(**args)
    new(**args).call
  end

  def initialize(
    cart:,
    user: nil,
    name: nil,
    email: nil,
    phone_number: nil,
    shipping_address_params: nil,
    billing_address_params: nil,
    shipping_address_id: nil,
    billing_address_id: nil,
    currency: nil,
    apply_promotions: true,
    idempotency_key: nil,
    shipping_method: nil,
    store_address_id: nil,
    payment_method: 'cod'
  )
    @cart = cart
    @user = user
    @shipping_address_params = shipping_address_params
    @billing_address_params = billing_address_params
    @shipping_address_id = shipping_address_id
    @billing_address_id = billing_address_id
    @currency = currency || 'VND'
    @apply_promotions = apply_promotions
    @idempotency_key = idempotency_key
    @name = name
    @email = email
    @phone_number = phone_number
    @shipping_method = shipping_method
    @store_address_id = store_address_id
    @payment_method = payment_method
  end

  def call
    validate_cart!
    check_idempotency

    # Use transaction with cart locking to prevent concurrent checkouts
    Cart.transaction do
      lock_cart!
      check_already_checked_out!

      # Process addresses
      @shipping_address = resolve_address(@shipping_address_id, @shipping_address_params, 'shipping')
      @billing_address = resolve_address(@billing_address_id, @billing_address_params, 'billing')

      # Create order with calculated totals
      @order = build_order
      @order.save!

      # Snapshot cart items to order items
      create_order_items!

      # Apply promotions and create usage records
      apply_promotions_to_order! if @apply_promotions

      # Reload the order object to ensure the promotions association is loaded
      # from the database before recalculating totals. This is the key fix.
      @order.reload

      # Recalculate final totals using the robust method on the Order model.
      # This will calculate discounts from the newly applied promotions.
      @order.recalculate_totals!

      # Update cart status
      mark_cart_checked_out!

      # Create emailed cart record for guest checkouts
      create_emailed_cart_record! if @cart.guest_email.present?

      Rails.logger.info "[OrderCreatorService] order created order_id=#{@order.id} order_number=#{@order.order_number} cart_id=#{@cart.id}"
    end

    # Enqueue notification job outside transaction
    enqueue_notification_job

    @order
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "[OrderCreatorService] validation failed: #{e.record.errors.full_messages.join(', ')}"
    raise
  rescue StandardError => e
    Rails.logger.error "[OrderCreatorService] error creating order: #{e.class} #{e.message}"
    raise
  end

  private

  # Validate cart presence and items
  def validate_cart!
    raise ArgumentError, 'Cart is required' unless @cart.present?
    raise EmptyCartError, 'Cart is empty' unless @cart.cart_items.any?
  end

  # Check for existing order with same idempotency key
  def check_idempotency
    return unless @idempotency_key.present?

    existing_order = Order.find_by("metadata->>'idempotency_key' = ?", @idempotency_key)
    existing_order if existing_order
  end

  # Lock cart for update to prevent concurrent checkouts (SELECT FOR UPDATE)
  def lock_cart!
    @cart.lock!
  end

  # Check if cart is already checked out
  def check_already_checked_out!
    if @cart.checked_out?
      existing_order = Order.find_by(cart_id: @cart.id)
      if existing_order
        Rails.logger.info "[OrderCreatorService] cart already checked out cart_id=#{@cart.id} order_id=#{existing_order.id}"
        raise AlreadyCheckedOutError, "Cart already checked out. Order: #{existing_order.order_number}"
      end
      raise AlreadyCheckedOutError, 'Cart already checked out'
    end
  end

  # Resolve address from ID or params
  def resolve_address(address_id, address_params, address_type)
    if address_id.present?
      address = Address.find(address_id)
      validate_address_ownership!(address, address_type)
      address
    elsif address_params.present?
      create_address(address_params, address_type)
    end
  end

  # Validate address belongs to user
  def validate_address_ownership!(address, address_type)
    return unless @user.present?

    if address.addressable_type == 'User' && address.addressable_id != @user.id
      raise InvalidAddressError, "#{address_type.capitalize} address does not belong to user"
    end
  end

  # Create new address from params
  def create_address(params, address_type)
    addressable = @user || @cart

    Address.create!(
      addressable: addressable,
      address: params[:address] || params[:line1],
      city: params[:city],
      district: params[:district],
      ward: params[:ward],
      phone_numbers: [params[:phone] || params[:phone_number]].compact
    )
  rescue ActiveRecord::RecordInvalid => e
    raise InvalidAddressError, "Invalid #{address_type} address: #{e.message}"
  end

  def build_order
    order_attributes = {
      user: @user,
      cart: @cart,
      order_number: generate_order_number,
      currency: @currency,
      status: 'awaiting_payment',
      # Prioritize provided params, then user attributes, for contact info
      name: @name.presence || @user&.name,
      email: @email.presence || @user&.email,
      phone_number: @phone_number.presence || @user&.phone_number,
      shipping_address: @shipping_address,
      billing_address: @billing_address,
      shipping_method: @shipping_method,
      store_address_id: @store_address_id,
      payment_method: @payment_method,
      metadata: build_order_metadata
    }

    Order.new(order_attributes)
  end

  # Generate unique order number
  def generate_order_number
    loop do
      # Format: ORD-YYYYMMDD-RANDOMHEX
      number = "ORD-#{Time.current.strftime('%Y%m%d')}-#{SecureRandom.hex(4).upcase}"
      break number unless Order.exists?(order_number: number)
    end
  end

  # Build order metadata including idempotency key
  def build_order_metadata
    metadata = {
      cart_id: @cart.id.to_s,
      cart_type: @cart.cart_type,
      created_at: Time.current.iso8601
    }
    metadata['idempotency_key'] = @idempotency_key if @idempotency_key.present?
    metadata
  end

  # Snapshot cart items to order items
  def create_order_items!
    @cart.cart_items.each do |cart_item|
      create_order_item_from_cart_item(cart_item)
    end
  end

  # Create single order item from cart item
  def create_order_item_from_cart_item(cart_item)
    unit_price_vnd = calculate_unit_price_vnd(cart_item)
    original_unit_price_vnd = calculate_original_unit_price_vnd(cart_item)

    @order.order_items.create!(
      product_id: cart_item.product_id,
      product_variant_id: cart_item.product_variant_id,
      product_name: cart_item.product_name,
      product_image_url: cart_item.product_image_url,
      quantity: cart_item.quantity,
      unit_price_vnd: unit_price_vnd,
      original_unit_price_vnd: original_unit_price_vnd,
      subtotal_vnd: unit_price_vnd * cart_item.quantity,
      currency: @currency,
      metadata: build_order_item_metadata(cart_item)
    )
  end

  # Calculate unit price in cents from cart item
  def calculate_unit_price_vnd(cart_item)
    BigDecimal(cart_item.current_price.to_s).to_i
  end

  # Calculate original unit price in cents from cart item
  def calculate_original_unit_price_vnd(cart_item)
    BigDecimal(cart_item.original_price.to_s).to_i
  end

  # Build order item metadata with additional product details
  def build_order_item_metadata(cart_item)
    metadata = {
      added_at: cart_item.added_at&.iso8601,
      cart_item_id: cart_item.id.to_s
    }

    # Add product variant details if present
    if cart_item.product_variant.present?
      metadata['variant_name'] = cart_item.product_variant.name
      metadata['variant_sku'] = cart_item.product_variant.sku
    end

    metadata
  end

  # Validates and applies promotions from the cart to the order.
  # This method validates the entire batch of promotions before applying any,
  # ensuring that invalid combinations fail loudly and atomically.
  def apply_promotions_to_order!
    promos_from_cart = @cart.promotions.to_a
    return if promos_from_cart.empty?

    # --- Pre-validation Step ---
    # 1. Check for invalid (expired, used-up) promotions first.
    invalid_promo = promos_from_cart.find { |p| !p.applies_now? || p.used_up? }
    if invalid_promo
      raise InvalidPromotionCombinationError, "Promotion '#{invalid_promo.code}' is not valid."
    end

    # 2. Check for stacking violations within the batch.
    non_stackable_promo = promos_from_cart.find { |p| !p.stackable? }
    if non_stackable_promo && promos_from_cart.size > 1
      conflicting_codes = promos_from_cart.map(&:code).join(', ')
      raise InvalidPromotionCombinationError, "The non-stackable promotion '#{non_stackable_promo.code}' cannot be combined with other promotions: [#{conflicting_codes}]."
    end

    # --- Application Step ---
    # If all validations pass, apply the promotions.
    Rails.logger.info "[OrderCreatorService] All #{promos_from_cart.count} promotions are valid. Applying to order #{@order.order_number}"
    promos_from_cart.each do |promo|
      @order.promotion_usages.create!(promotion: promo, user: @user)
    end
  end

  # Mark cart as checked out
  def mark_cart_checked_out!
    cart_metadata = @cart.metadata || {}
    cart_metadata['order_id'] = @order.id.to_s
    cart_metadata['checked_out_at'] = Time.current.iso8601

    @cart.update!(
      status: 'checked_out',
      metadata: cart_metadata
    )
  end

  # Create emailed cart record for guest checkout tracking
  def create_emailed_cart_record!
    EmailedCart.create!(
      cart: @cart,
      email: @cart.guest_email,
      recipient_type: @cart.cart_type,
      sent_at: Time.current,
      expires_at: 30.days.from_now
    )
  rescue ActiveRecord::RecordInvalid => e
    # Log but don't fail the order creation if emailed cart fails
    Rails.logger.warn "[OrderCreatorService] failed to create emailed cart: #{e.message}"
  end

  # Enqueue notification job to send confirmation email
  def enqueue_notification_job
    OrderNotificationJob.perform_later(@order.id)
    Rails.logger.info "[OrderCreatorService] notification job enqueued for order_id=#{@order.id}"

    # Send admin notifications immediately only for non-onepay payment methods
    # For onepay, admin notifications will be sent after payment is confirmed
    AdminOrderNotificationJob.perform_later(@order.id)
    Rails.logger.info "[OrderCreatorService] admin notification job enqueued for order_id=#{@order.id}"
  end
end
