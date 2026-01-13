# frozen_string_literal: true

require 'securerandom'

puts 'Seeding orders...'

# Idempotent seed for orders, simulating user actions via services.
# --- Pre-flight Checks ---
unless User.exists? && ProductVariant.exists? && Promotion.exists?
  puts "⚠ Skipping order seeds - need users, product variants, and promotions first."
  return
end

orders_created = 0

# --- Helper Methods ---
def create_vietnamese_address_params(index: 0)
  addresses = [
    { address: "123 Đường Nguyễn Huệ", city: "Hồ Chí Minh", district: "Quận 1", ward: "Phường Bến Nghé", phone_number: "0901234567" },
    { address: "456 Đường Lê Lợi", city: "Hồ Chí Minh", district: "Quận 3", ward: "Phường Võ Thị Sáu", phone_number: "0912345678" },
    { address: "789 Đường Trần Hưng Đạo", city: "Hà Nội", district: "Quận Hoàn Kiếm", ward: "Phường Hàng Bạc", phone_number: "0923456789" },
  ]
  addresses[index % addresses.length]
end

def create_seed_cart(user: nil, guest_email: nil, variant:, qty: 1, session_suffix:)
  session_id = user ? "seed-#{session_suffix}-#{user.id}" : "seed-#{session_suffix}-#{guest_email.hash}"
  cart = Cart.find_or_create_by!(session_id: session_id) do |c|
    c.user = user
    c.guest_email = guest_email
    c.cart_type = user ? 'authenticated' : 'anonymous'
    c.metadata = { source: 'seed', purpose: 'order_seed' }
  end
  cart.update(status: 'active') if cart.checked_out?
  cart.promotions.clear
  cart.cart_items.destroy_all
  cart.cart_items.create!(product: variant.product, product_variant: variant, quantity: qty)
  cart.reload
end

def order_exists_for_cart?(cart)
  return false unless cart&.persisted?
  Order.exists?(cart_id: cart.id)
end

# --- Seeding Logic ---

ActiveRecord::Base.transaction do
  puts "\n--- Seeding Comprehensive Order Cases by Simulating User Actions ---"

  users = User.order(:created_at).limit(5).to_a
  variants = ProductVariant.includes(:product).order(:created_at).limit(10).to_a
  stackable_promos = Promotion.active.where(stackable: true).to_a
  non_stackable_promo = Promotion.active.find_by(stackable: false)
  expired_promo = Promotion.where('ends_at < ?', Time.current).first

  # --- Test Cases ---

  5.times do |i|
    puts "\n--- Seeding Order Batch ##{i + 1}/5 ---"

  # Case 1: Basic order, no promotions
  begin
    cart1 = create_seed_cart(user: users[0], variant: variants[0], qty: 1, session_suffix: 'case1')
    unless order_exists_for_cart?(cart1)
      params = { cart: cart1, user: users[0], shipping_address_params: create_vietnamese_address_params(index: 0), shipping_method: 'ship_to_address' }
      order = OrderCreatorService.call(**params.merge(apply_promotions: false))
      puts "✓ 1. Basic Order: OK - #{order.order_number}"
      orders_created += 1
    end
  rescue => e
    puts "✗ Case 1 Failed: #{e.message}"
  end

  # Case 2: Order with multiple stackable promotions
  begin
    cart2 = create_seed_cart(user: users[1], variant: variants[1], qty: 2, session_suffix: 'case2')
    unless order_exists_for_cart?(cart2)
      if stackable_promos.size >= 2
        promos_to_apply = stackable_promos.sample(2)
        promos_to_apply.each { |p| ApplyPromotionCodeService.new(redeemable: cart2, code: p.code, user: users[1]).call }

        params = { cart: cart2, user: users[1], shipping_address_params: create_vietnamese_address_params(index: 1), shipping_method: 'ship_to_address', apply_promotions: true }
        order = OrderCreatorService.call(**params)
        order.update!(status: 'paid')
        puts "✓ 2. Multi-Promo Order: OK - #{order.order_number} with #{order.promotions.count} promos."
        orders_created += 1
      else
        puts "⚠️  Case 2 Skipped: Not enough stackable promotions found."
      end
    end
  rescue => e
    puts "✗ Case 2 Failed: #{e.message}"
  end

  # Case 3: Stacking violation test (should fail at service level)
  puts "\n--- Seeding Validation Test Cases ---"
  begin
    cart3 = create_seed_cart(user: users[2], variant: variants[2], qty: 1, session_suffix: 'case3')
    if stackable_promos.any? && non_stackable_promo
      puts "-   3. Testing stacking violation..."
      # First, apply a stackable one
      ApplyPromotionCodeService.new(redeemable: cart3, code: stackable_promos.first.code, user: users[2]).call
      # Now, attempt to apply a non-stackable one, which should fail
      result = ApplyPromotionCodeService.new(redeemable: cart3, code: non_stackable_promo.code, user: users[2]).call

      if !result.success? && result.error.include?('cannot be combined')
        puts "  ✓ Correctly prevented stacking at the cart level."
      else
        puts "  ✗ FAILED TEST: Did not prevent stacking as expected."
      end
    else
      puts "⚠️  Case 3 Skipped: Need both a stackable and non-stackable promo to test."
    end
  rescue => e
    puts "✗ Case 3 Failed with unexpected error: #{e.message}"
  end

  # Case 4: Expired promotion test (guaranteed test)
  begin
    cart4 = create_seed_cart(user: users[3], variant: variants[3], qty: 1, session_suffix: 'case4')
    puts "-   4. Testing expired promotion rejection..."

    # Create a promotion that will expire almost immediately
    expired_promo = Promotion.find_or_create_by!(code: 'seed-test-expired') do |p|
      p.title = 'Test Expiring Promo'
      p.discount_type = 'fixed'
      p.discount_value = 1
      p.active = true
      p.ends_at = Time.current + 1.second
    end

    # Wait for it to expire
    puts "    (waiting 2 seconds for promo to expire...)"
    sleep 2

    result = ApplyPromotionCodeService.new(redeemable: cart4, code: expired_promo.code, user: users[3]).call
    if !result.success? && result.error.include?('no longer active')
      puts "  ✓ Correctly rejected expired promo '#{expired_promo.code}'."
    else
      puts "  ✗ FAILED TEST: Did not reject expired promo as expected."
    end
  rescue => e
    puts "✗ Case 4 Failed with unexpected error: #{e.message}"
  end

  # Case 5: Duplicate promotion test (should fail at service level)
  begin
    cart5 = create_seed_cart(user: users[4], variant: variants[4], qty: 1, session_suffix: 'case5')
    if stackable_promos.any?
      puts "-   5. Testing duplicate promotion rejection..."
      promo_to_apply = stackable_promos.first
      # Apply it once, should succeed
      ApplyPromotionCodeService.new(redeemable: cart5, code: promo_to_apply.code, user: users[4]).call
      # Apply it a second time, should fail
      result = ApplyPromotionCodeService.new(redeemable: cart5, code: promo_to_apply.code, user: users[4]).call

      if !result.success? && result.error.include?('has already been applied')
        puts "  ✓ Correctly rejected duplicate promo code '#{promo_to_apply.code}'."
      else
        puts "  ✗ FAILED TEST: Did not reject duplicate promo code as expected."
      end
    else
      puts "⚠️  Case 5 Skipped: No stackable promotion found to test."
    end
  rescue => e
    puts "✗ Case 5 Failed with unexpected error: #{e.message}"
  end

  # Case 6: Guest order with a valid promotion
  begin
    cart6 = create_seed_cart(guest_email: 'guest.promo.final@example.com', variant: variants[5], qty: 2, session_suffix: 'case6')
    unless order_exists_for_cart?(cart6)
      if stackable_promos.any?
        promo_to_apply = stackable_promos.first
        ApplyPromotionCodeService.new(redeemable: cart6, code: promo_to_apply.code).call

        params = { cart: cart6, shipping_address_params: create_vietnamese_address_params(index: 1), shipping_method: 'ship_to_address', apply_promotions: true }
        order = OrderCreatorService.call(**params)
        order.update!(status: 'paid')
        puts "✓ 6. Guest Order with Promo: OK - #{order.order_number} with promo '#{promo_to_apply.code}'."
        orders_created += 1
      else
        puts "⚠️  Case 6 Skipped: No stackable promotion found for guest test."
      end
    end
  rescue => e
    puts "✗ Case 6 Failed: #{e.message}"
  end

  # Case 7: Order with overridden customer name
  begin
    # Use a different user/variant to avoid conflicts if loop is > 1
    user7 = users[(i + 4) % users.size]
    variant7 = variants[(i + 6) % variants.size]
    cart7 = create_seed_cart(user: user7, variant: variant7, qty: 1, session_suffix: "case7-#{i}")
    unless order_exists_for_cart?(cart7)
      override_name = "Gift for #{user7.name}"
      puts "-   7. Testing name override for user '#{user7.name}'..."

      params = {
        cart: cart7,
        user: user7,
        name: override_name, # Explicitly providing a different name
        shipping_address_params: create_vietnamese_address_params(index: 2),
        shipping_method: 'ship_to_address',
        apply_promotions: false
      }
      order = OrderCreatorService.call(**params)

      if order.name == override_name
        puts "  ✓ Correctly applied overridden name to order #{order.order_number}."
        orders_created += 1
      else
        puts "  ✗ FAILED TEST: Name override was not applied. Order name is '#{order.name}'."
      end
    end
  rescue => e
    puts "✗ Case 7 Failed with unexpected error: #{e.message}"
  end

  # Case 8: Order with overridden customer contact info
  begin
    # Use a different user/variant to avoid conflicts if loop is > 1
    user8 = users[(i + 2) % users.size]
    variant8 = variants[(i + 8) % variants.size]
    cart8 = create_seed_cart(user: user8, variant: variant8, qty: 1, session_suffix: "case8-#{i}")
    unless order_exists_for_cart?(cart8)
      override_params = {
        name: "Gift Recipient #{i}",
        email: "gift.recipient.#{i}@example.com",
        phone_number: "0987654321"
      }
      puts "-   8. Testing contact info override for user '#{user8.name}'..."

      params = {
        cart: cart8,
        user: user8,
        shipping_address_params: create_vietnamese_address_params(index: 1),
        shipping_method: 'ship_to_address'
      }.merge(override_params)

      order = OrderCreatorService.call(**params)

      if order.name == override_params[:name] && order.email == override_params[:email] && order.phone_number == override_params[:phone_number]
        puts "  ✓ Correctly applied overridden contact info to order #{order.order_number}."
        orders_created += 1
      else
        puts "  ✗ FAILED TEST: Contact info override was not applied correctly."
      end
    end
  rescue => e
    puts "✗ Case 8 Failed with unexpected error: #{e.message}"
  end

  # Case 9: Guest order with provided contact info
  begin
    variant9 = variants[(i + 9) % variants.size]
    cart9 = create_seed_cart(guest_email: "guest.#{i}@example.com", variant: variant9, qty: 1, session_suffix: "case9-#{i}")
    unless order_exists_for_cart?(cart9)
      guest_params = {
        name: "Guest Customer #{i}",
        email: "guest.checkout.#{i}@example.com",
        phone_number: "0911223344"
      }
      puts "-   9. Testing guest checkout with provided contact info..."

      params = {
        cart: cart9,
        user: nil, # Explicitly a guest
        shipping_address_params: create_vietnamese_address_params(index: 0),
        shipping_method: 'ship_to_address'
      }.merge(guest_params)

      order = OrderCreatorService.call(**params)

      if order.name == guest_params[:name] && order.email == guest_params[:email]
        puts "  ✓ Correctly created guest order #{order.order_number} with provided info."
        orders_created += 1
      else
        puts "  ✗ FAILED TEST: Guest order did not save provided contact info."
      end
    end
  rescue => e
    puts "✗ Case 9 Failed with unexpected error: #{e.message}"
  end

  # Case 10: Guest order with a valid promotion
  begin
    variant10 = variants[(i + 10) % variants.size]
    cart10 = create_seed_cart(guest_email: "guest.promo.#{i}@example.com", variant: variant10, qty: 2, session_suffix: "case10-#{i}")
    unless order_exists_for_cart?(cart10)
      if stackable_promos.any?
        promo_to_apply = stackable_promos.sample
        ApplyPromotionCodeService.new(redeemable: cart10, code: promo_to_apply.code).call
        puts "-   10. Testing guest checkout with promo '#{promo_to_apply.code}'..."

        params = {
          cart: cart10,
          name: "Guest With Promo #{i}",
          email: "guest.with.promo.#{i}@example.com",
          shipping_address_params: create_vietnamese_address_params(index: 1),
          shipping_method: 'ship_to_address',
          apply_promotions: true
        }
        order = OrderCreatorService.call(**params)
        order.update!(status: 'paid')
        if order.promotions.include?(promo_to_apply)
          puts "  ✓ Correctly created guest order #{order.order_number} with promo."
          orders_created += 1
        else
          puts "  ✗ FAILED TEST: Guest order with promo did not have promotion applied."
        end
      else
        puts "⚠️  Case 10 Skipped: No stackable promotion found for guest test."
      end
    end
  rescue => e
    puts "✗ Case 10 Failed: #{e.message}"
  end

  # Case 11: Percentage discount cap enforcement test
  begin
    puts "\n--- Case 11: Testing percentage promotion cap enforcement ---"
    cart11 = create_seed_cart(user: users[0], variant: variants[0], qty: 1, session_suffix: 'case11')
    unless order_exists_for_cart?(cart11)
      promo_cap = Promotion.find_or_create_by!(code: 'seed-percent-cap') do |p|
        p.title = 'Seed Percent Cap Promo'
        p.discount_type = 'percentage'
        p.discount_value = 50
        p.max_discount_amount_vnd = 10_000
        p.active = true
      end

      # Apply the promo to the cart
      ApplyPromotionCodeService.new(redeemable: cart11, code: promo_cap.code, user: users[0]).call

      params = { cart: cart11, user: users[0], shipping_address_params: create_vietnamese_address_params(index: 0), shipping_method: 'ship_to_address', apply_promotions: true }
      order = OrderCreatorService.call(**params)

      # Calculate expected discount using Promotion model logic
      subtotal = order.subtotal_vnd
      expected_discount = promo_cap.apply_amount(subtotal).to_f.round(2).to_i

      if order.discount_vnd == expected_discount
        puts "  ✓ 11. Percentage cap applied correctly: expected #{expected_discount}, got #{order.discount_vnd}."
        orders_created += 1
      else
        puts "  ✗ 11. Percentage cap mismatch: expected #{expected_discount}, got #{order.discount_vnd}."
      end
    end
  rescue => e
    puts "✗ Case 11 Failed: #{e.message}"
  end
  end
end

puts "\n" + "="*60
puts "Orders Seeding Complete!"
puts "="*60
puts "✓ Created: #{orders_created} orders"
