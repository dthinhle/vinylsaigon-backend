# Seed product variants for each product
# This file assumes products have already been seeded.

require 'faker'
require 'securerandom'
require 'set'

puts "Seeding product variants..."


# Vietnamese-style attribute pools
COLORS = %w[Đen Trắng Đỏ Xanh Xám Vàng Hồng Tím Nâu Cam].freeze
SIZES = %w[Nhỏ Vừa Lớn XL XXL].freeze
MATERIALS = ["Nhựa", "Kim loại", "Gỗ", "Da", "Vải", "Thép không gỉ"].freeze
FEATURES = ["Chống nước", "Không dây", "Cảm ứng", "Pin lâu", "Chống ồn", "Siêu nhẹ"].freeze


images = Dir.glob(Rails.root.join('db', 'seeds', 'images', '*.webp'))

variants_created = 0
images_attached = 0

# Helper to create variants for a product, idempotently
def create_variants_for(product, variants)
  variants.each do |variant|
    next if ProductVariant.exists?(product_id: product.id, sku: variant[:sku])
    # Ensure slug is unique in DB
    while ProductVariant.exists?(slug: variant[:slug])
      variant[:slug] = generate_unique_slug(variant)
    end
    ProductVariant.create!(
      product_id: product.id,
      name: variant[:name],
      sku: variant[:sku],
      slug: variant[:slug],
      current_price: variant[:current_price],
      original_price: variant[:original_price],
      stock_quantity: variant[:stock_quantity],
      variant_attributes: variant[:variant_attributes] || {},
      status: variant[:status] || "active",
      sort_order: variant[:sort_order],
      deleted_at: nil
    )
    puts "  ✓ Created variant '#{variant[:name]}' for #{product.name}"
  end

  if product.product_variants.count > 1 && product.product_variants.where(name: 'Default').exists?
    default_variant = product.product_variants.find_by(name: 'Default')
    default_variant.destroy
    puts "  ✓ Removed default variant for #{product.name}"
  end
end

def random_variant_attributes
  # Curated list of music/audio-related attribute keys
  keys = [
    "Độ thoải mái", "Chất âm", "Công suất", "Tần số", "Bluetooth", "Pin",
    "Micro", "Chống ồn", "Độ bền", "Độ nhạy", "Trở kháng", "Kết nối",
    "Thời lượng pin", "Sạc nhanh", "Đèn LED", "Chất liệu housing",
    "Độ méo tiếng", "Tương thích", "Khoảng cách kết nối", "Cảm biến",
  ]
  # Randomly select 3-5 keys for each variant
  selected_keys = keys.sample(rand(1..3))
  attrs = {}

  selected_keys.each do |key|
    # Generate 1-2 paragraphs for each attribute value
    attrs[key] = Faker::Lorem.sentence
  end

  attrs
end

def random_variant_name(attrs)
  # Join up to 3 attribute keys and their values for the name
  attrs.to_a.sample(3).map { |k, v| "#{k}" }.join(", ")
end

# Generate a unique slug based on attributes and a random hex suffix
def generate_unique_slug(variant)
  base = [
    variant[:sku],
    variant[:name].parameterize,
    SecureRandom.hex(4),
  ].join('-')
  base.downcase.gsub(/[^a-z0-9\-]/, '-')
end

# Track slugs generated in this seed run to avoid duplicates
$generated_variant_slugs ||= Set.new

# Seed for specific products with known SKUs
mouse = Product.find_by(sku: "WMOUSE-1001")
if mouse
  variants = []
  3.times do |i|
    attrs = random_variant_attributes
    sku = "WMOUSE-1001-VN-#{i+1}"
    slug = generate_unique_slug(
      name: random_variant_name(attrs),
      sku: sku
    )
    # Ensure slug is unique in this seed run
    while $generated_variant_slugs.include?(slug)
      slug = generate_unique_slug(
        name: random_variant_name(attrs),
        sku: sku
      )
    end
    $generated_variant_slugs << slug
    variants << {
      name: random_variant_name(attrs),
      sku: sku,
      slug: slug,
      current_price: nil,
      original_price: 399_900,
      stock_quantity: rand(10..50),
      variant_attributes: attrs,
      sort_order: i + 1
    }
  end
  create_variants_for(mouse, variants)
  variants_created += variants.size
end

keyboard = Product.find_by(sku: 'MKEY-2002-TEST')
if keyboard
  variants = []
  3.times do |i|
    attrs = random_variant_attributes
    sku = "MKEY-2002-VN-#{i+1}"
    slug = generate_unique_slug(
      name: random_variant_name(attrs),
      sku: sku
    )
    while $generated_variant_slugs.include?(slug)
      slug = generate_unique_slug(
        name: random_variant_name(attrs),
        sku: sku
      )
    end
    $generated_variant_slugs << slug
    price_variant = keyboard.current_price + rand(-3..3) * 100_000
    variants << {
      name: random_variant_name(attrs),
      sku: sku,
      slug: slug,
      current_price: price_variant > 0 ? price_variant : keyboard.current_price,
      original_price: 899_900,
      stock_quantity: rand(10..50),
      variant_attributes: attrs,
      sort_order: i + 1
    }
  end
  create_variants_for(keyboard, variants)
  variants_created += variants.size
end

# Seed for all other seed products (SEEDSKU3, SEEDSKU4, ...)
(3..30).each do |n|
  sku = "SEEDSKU#{n}"
  product = Product.find_by(sku: sku)
  next unless product

  variants = []
  rand(1..3).times do |i|
    attrs = random_variant_attributes
    vsku = "#{sku}-VN-#{i+1}"
    # Generate slug using parameterized keys and SecureRandom, ensure uniqueness in seed run and DB
    slug = generate_unique_slug(
      name: random_variant_name(attrs),
      sku: vsku
    )
    while $generated_variant_slugs.include?(slug) || ProductVariant.exists?(slug: slug)
      slug = generate_unique_slug(
        name: random_variant_name(attrs),
        sku: vsku
      )
    end
    $generated_variant_slugs << slug
    price_variant = product.current_price + rand(-3..3) * 100_000
    original_price = [price_variant - rand(0..2) * 100_000, rand(10..25) * 100_000].max
    variants << {
      name: random_variant_name(attrs),
      sku: vsku,
      slug: slug,
      current_price: price_variant > 0 ? price_variant : product.current_price,
      original_price: original_price,
      stock_quantity: rand(5..30),
      variant_attributes: attrs,
      sort_order: i + 1
    }
  end
  create_variants_for(product, variants)
  variants_created += variants.size
end

ProductVariant.all.each do |variant|
  # Attach random images to each variant
  attached_images = images.sample(rand(1..3))
  attached_images.each_with_index do |image_path, idx|
    img = variant.product_images.create!(position: idx + 1)
    img.image.attach(
      io: File.open(image_path),
      filename: File.basename(image_path),
      content_type: 'image/webp'
    )
    images_attached += 1
  end
end

puts "\n" + "="*60
puts "Product Variants Seeding Complete!"
puts "="*60
puts "✓ Created: #{variants_created} product variants"
puts "✓ Images attached: #{images_attached}"

puts "Product variants seeded."
