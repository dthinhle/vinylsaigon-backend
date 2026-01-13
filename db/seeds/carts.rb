# Idempotent seed for carts and cart_items.
# Uses find_or_initialize_by + save! so repeated runs are safe.
if defined?(Cart)
  require 'securerandom'
  puts "Seeding carts..."

  variant = ProductVariant.first if defined?(ProductVariant)
  if defined?(ProductVariant) && variant.nil?
    puts "[seeds/carts] no product variants found; cart_items will be skipped."
  end

  carts_created = 0
  cart_items_created = 0

  ActiveRecord::Base.transaction do
    # Anonymous active cart (session-based)
    anon_cart = Cart.find_or_initialize_by(session_id: 'seed-session-anon-active')
    anon_cart.status = 'active'
    anon_cart.guest_email = nil
    anon_cart.metadata = (anon_cart.metadata || {}).merge(source: 'seed')
    anon_cart.last_activity_at = Time.current
    anon_cart.expires_at = 3.days.from_now
    anon_cart.save!
    carts_created += 1
    puts "  ✓ Created anonymous active cart"

    if variant
      2.times do |i|
        product = variant.product
        item = CartItem.find_or_initialize_by(cart: anon_cart, product_id: product.id, product_variant_id: variant.id)
        item.quantity ||= (i.zero? ? 1 : 1)
        item.current_price = variant.current_price || variant.original_price || 100_000
        item.original_price = variant.original_price || variant.current_price || 100_000
        item.product_name = product.name
        item.added_at ||= Time.current
        item.expires_at ||= 3.days.from_now
        item.save!
        cart_items_created += 1
      end
      puts "  ✓ Added #{cart_items_created} items to anonymous cart"
    else
      puts "[seeds/carts] skipped cart_items for anonymous cart: no variants"
    end

    # Authenticated cart linked to first user
    if defined?(User) && (user = User.first)
      auth_cart = Cart.find_or_initialize_by(session_id: "seed-session-auth-#{user.id}")
      auth_cart.user_id = user.id
      auth_cart.cart_type = 'authenticated'
      auth_cart.status = 'active'
      auth_cart.metadata = (auth_cart.metadata || {}).merge(source: 'seed')
      auth_cart.last_activity_at = Time.current
      auth_cart.expires_at = 3.days.from_now
      auth_cart.save!
      carts_created += 1
      puts "  ✓ Created authenticated cart for user #{user.email}"

      if variant
        item = CartItem.find_or_initialize_by(cart: auth_cart, product_id: variant.product_id, product_variant_id: variant.id)
        item.quantity ||= 1
        price = variant.current_price || variant.original_price || 10_000
        item.current_price = price
        item.original_price = price
        item.product_name = variant.product.name
        item.save!
        cart_items_created += 1
        puts "  ✓ Added item to authenticated cart"
      else
        puts "[seeds/carts] skipped cart_items for authenticated cart: no variants"
      end
    else
      puts "[seeds/carts] no users found; skipping authenticated cart"
    end

    # Expired cart
    expired_cart = Cart.find_or_initialize_by(session_id: 'seed-session-expired')
    expired_cart.status = 'expired'
    expired_cart.metadata = (expired_cart.metadata || {}).merge(source: 'seed')
    expired_cart.last_activity_at = 10.days.ago
    expired_cart.expires_at = 5.days.ago
    expired_cart.save!
    carts_created += 1
    puts "  ✓ Created expired cart"

    if variant
      item = CartItem.find_or_initialize_by(cart: expired_cart, product_id: variant.product_id, product_variant_id: variant.id)
      item.quantity ||= 1
      price = variant.current_price || variant.original_price || 10_000
      item.current_price = price
      item.original_price = price
      item.product_name = variant.product.name
      item.added_at ||= 10.days.ago
      item.expires_at ||= 5.days.ago
      item.save!
      cart_items_created += 1
      puts "  ✓ Added item to expired cart"
    else
      puts "[seeds/carts] skipped cart_items for expired cart: no variants"
    end

    # Emailed cart (guest_email + EmailedCart)
    emailed_cart = Cart.find_or_initialize_by(session_id: 'seed-session-emailed')
    guest_email = 'guest+seed@example.com'
    emailed_cart.guest_email = guest_email
    emailed_cart.status = 'emailed'
    emailed_cart.metadata = (emailed_cart.metadata || {}).merge(source: 'seed', emailed: true)
    emailed_cart.last_activity_at = Time.current
    emailed_cart.expires_at = 7.days.from_now
    emailed_cart.save!
    carts_created += 1
    puts "  ✓ Created emailed cart"

    if defined?(EmailedCart)
      ec = EmailedCart.find_or_initialize_by(cart: emailed_cart, email: guest_email)
      ec.expires_at = 7.days.from_now
      ec.sent_at = Time.current
      ec.recipient_type ||= 'anonymous'
      ec.save!
      puts "  ✓ Created emailed cart record"
    else
      puts "[seeds/carts] EmailedCart model not defined; skipping emailed carts"
    end

    # Cart with free installment products (all items have free_installment_fee = true)
    if defined?(User) && (user = User.second || User.first)
      free_variants = ProductVariant.joins(:product).where(products: { free_installment_fee: true }).limit(3)
      if free_variants.any?
        free_cart = Cart.find_or_initialize_by(session_id: "seed-session-free-installment-#{user.id}")
        free_cart.user_id = user.id
        free_cart.cart_type = 'authenticated'
        free_cart.status = 'active'
        free_cart.metadata = (free_cart.metadata || {}).merge(source: 'seed', has_free_installment: true)
        free_cart.last_activity_at = Time.current
        free_cart.expires_at = 3.days.from_now
        free_cart.save!
        carts_created += 1
        puts "  ✓ Created cart with Free Installment Fee products"

        free_variants.each do |variant|
          item = CartItem.find_or_initialize_by(cart: free_cart, product_id: variant.product_id, product_variant_id: variant.id)
          item.quantity ||= 1
          price = variant.current_price || variant.original_price || 100_000
          item.current_price = price
          item.original_price = price
          item.product_name = variant.product.name
          item.save!
          cart_items_created += 1
        end
        puts "  ✓ Added #{free_variants.count} free installment items"
      end
    end

    # Cart with mixed installment products (some free, some not)
    if defined?(User) && (user = User.third || User.second || User.first)
      free_variant = ProductVariant.joins(:product).where(products: { free_installment_fee: true }).first
      regular_variant = ProductVariant.joins(:product).where(products: { free_installment_fee: false }).first

      if free_variant && regular_variant
        mixed_cart = Cart.find_or_initialize_by(session_id: "seed-session-mixed-installment-#{user.id}")
        mixed_cart.user_id = user.id
        mixed_cart.cart_type = 'authenticated'
        mixed_cart.status = 'active'
        mixed_cart.metadata = (mixed_cart.metadata || {}).merge(source: 'seed', has_mixed_installment: true)
        mixed_cart.last_activity_at = Time.current
        mixed_cart.expires_at = 3.days.from_now
        mixed_cart.save!
        carts_created += 1
        puts "  ✓ Created cart with mixed Free Installment Fee products"

        [free_variant, regular_variant].each do |variant|
          item = CartItem.find_or_initialize_by(cart: mixed_cart, product_id: variant.product_id, product_variant_id: variant.id)
          item.quantity ||= 1
          price = variant.current_price || variant.original_price || 100_000
          item.current_price = price
          item.original_price = price
          item.product_name = variant.product.name
          item.save!
          cart_items_created += 1
        end
        puts "  ✓ Added 2 items (1 free, 1 regular installment)"
      end
    end
  end

  puts "\n" + "="*60
  puts "Carts Seeding Complete!"
  puts "="*60
  puts "✓ Created: #{carts_created} carts"
  puts "✓ Created: #{cart_items_created} cart items"
else
  puts "Skipping carts seeds because Cart model is not defined yet."
end
