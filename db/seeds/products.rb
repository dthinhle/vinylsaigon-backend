# Fetch child categories for product assignment
child_categories = Category.where.not(parent_id: nil)
images = Dir.glob(Rails.root.join('db', 'seeds', 'images', '*.webp'))
brand_logo_images = Dir.glob(Rails.root.join('db', 'seeds', 'files', '*')).filter { |f| f.include?('brand-logo') }
brand_cover_images = Dir.glob(Rails.root.join('db', 'seeds', 'files', '*')).filter { |f| f.include?('brand-cover') }

puts 'Seeding products...'

brands_created = 0
collections_created = 0
products_created = 0
images_attached = 0

# Create Brands
puts 'Creating 20 brands...'
brands = []
(1..20).each do |i|
  brand_name = "Brand #{i}"
  brand = Brand.find_or_create_by!(name: brand_name) do |b|
    b.name = brand_name
 end
  brand_logo_image = brand_logo_images.sample
  brand_cover_image = brand_cover_images.sample
  if brand_logo_image && File.exist?(brand_logo_image)
    brand.logo.attach(
      io: File.open(brand_logo_image),
      filename: File.basename(brand_logo_image),
      content_type: Marcel::MimeType.for(brand_logo_image)
    ) unless brand.logo.attached?
    images_attached += 1
  end
  if brand_cover_image && File.exist?(brand_cover_image)
    brand.banner.attach(
      io: File.open(brand_cover_image),
      filename: File.basename(brand_cover_image),
      content_type: Marcel::MimeType.for(brand_cover_image)
    ) unless brand.banner.attached?
    images_attached += 1
  end
  brands_created += 1
  brands << brand
end

# Helper to create Lexical JSON from text
def text_to_lexical(text)
  {
    root: {
      children: [
        {
          type: "paragraph",
          children: [
            {
              type: "text",
              text: text,
              format: 0
            },
          ]
        },
      ],
      direction: nil,
      format: "",
      indent: 0,
      type: "root",
      version: 1
    }
  }
end

# Create Collections
puts 'Creating 2 collections...'
collections = []
(1..2).each do |i|
  collection_name = "Collection #{i}"
  collection = ProductCollection.find_or_create_by!(name: collection_name) do |c|
    c.name = collection_name
    c.description = Faker::Lorem.sentence
  end

  # Attach cover image and thumbnail using product images
  if images.any?
    cover_image = images.sample
    thumbnail_image = images.sample

    collection.banner.attach(
      io: File.open(cover_image),
      filename: "cover_#{File.basename(cover_image)}",
      content_type: 'image/webp'
    ) unless collection.banner.attached?

    collection.thumbnail.attach(
      io: File.open(thumbnail_image),
      filename: "thumb_#{File.basename(thumbnail_image)}",
      content_type: 'image/webp'
    ) unless collection.thumbnail.attached?
    images_attached += 2
  end

  collections_created += 1
  collections << collection
end

# Sample tags as string array
sample_tags = ['Tag1', 'Tag2', 'Tag3', 'Tag4', 'Tag5']

# Add realistic sample products
puts 'Creating initial products...'
products = []
products << Product.find_or_create_by!(sku: "WMOUSE-1001-TEST") do |product|
  product.name = "Wireless Ergonomic Mouse"
  product.description = text_to_lexical("A wireless ergonomic mouse designed for comfort and productivity. Features adjustable DPI and silent clicks.")
  product.short_description = "Wireless ergonomic mouse with adjustable DPI and silent clicks."
  product.status = "active"
 product.stock_status = "in_stock"
  product.stock_quantity = 50
  product.low_stock_threshold = 5
  product.weight = 0.15
  product.meta_title = "Wireless Ergonomic Mouse"
  product.meta_description = "Buy the best wireless ergonomic mouse for productivity and comfort."
  product.featured = true
 product.sort_order = 1
  product.slug = "wireless-ergonomic-mouse-test"
  product.flags = ["just arrived"]
  product.free_installment_fee = true  # Store pays Installment Fee
  product.brands = [brands.sample]
  product.category = child_categories.sample
  product.product_tags = sample_tags.sample(rand(1..3))
  product.product_attributes = {
    "Connectivity" => "Wireless 2.4GHz",
    "DPI" => "800-3200 DPI",
    "Battery Life" => "Up to 12 months",
    "Buttons" => "6 programmable buttons",
    "Compatibility" => "Windows, macOS, Linux",
    "Dimensions" => "120 x 74 x 45 mm",
    "Warranty" => "2 years manufacturer warranty"
 }
end
product = products.last
product.product_variants.first.update!(original_price: 399_900, current_price: 299_900)
products_created += 1

products << Product.find_or_create_by!(sku: "KBOARD-2002-TEST") do |product|
  product.name = "RGB Mechanical Gaming Keyboard"
  product.description = text_to_lexical("RGB mechanical gaming keyboard with blue switches, customizable macros, and detachable wrist rest.")
  product.short_description = "RGB mechanical gaming keyboard with blue switches."
  product.status = "active"
  product.stock_status = "in_stock"
  product.stock_quantity = 30
  product.low_stock_threshold = 3
  product.weight = 0.95
  product.meta_title = "Mechanical Gaming Keyboard"
  product.meta_description = "High-performance mechanical keyboard for gamers and professionals."
  product.featured = false
  product.sort_order = 2
  product.slug = "mechanical-gaming-keyboard-test"
  product.flags = []
  product.free_installment_fee = false  # Buyer pays the installment fee (default: not free for buyer)
  product.brands = [brands.sample]
  product.category = child_categories.sample
  product.product_tags = sample_tags.sample(rand(1..3))
  product.product_attributes = {
    "Switch Type" => "Blue mechanical switches",
    "Key Count" => "104 keys",
    "Backlighting" => "RGB with 16.8M colors",
    "Polling Rate" => "1000Hz",
    "N-Key Rollover" => "Full N-key rollover",
    "Connectivity" => "USB Type-C",
    "Features" => ["Detachable wrist rest", "Media controls", "Macro programming"].to_sentence,
    "Dimensions" => "440 x 130 x 40 mm",
    "Warranty" => "1 year limited warranty"
  }
end
product = products.last
product.product_variants.first.update!(original_price: 899_900, current_price: 699_900) if product.product_variants.any?
products_created += 1

puts "Seeding products to reach at least 60 total..."
(1..(60 - Product.count)).each do |i|
  original_price = rand(10.0..100.0).round(2) * 100_000
  current_price = (original_price - rand(1.0..50.0).round(2) * 100_000)
  current_price = original_price if current_price < 0

  # Randomly assign free_installment_fee to ~30% of products
  free_fee = (i % 3 == 0)

  product = Product.find_or_create_by!(sku: "SEEDSKU#{i + 1000}") do |p|  # Using different range to avoid conflicts
    p.name = "Seed Product #{i + 1000}"
    p.slug = "seed-product-#{i + 1000}"
    p.description = text_to_lexical("Seeded product for pagination test.")
    p.short_description = "Short description for Seed Product #{i + 1000}"
    p.stock_quantity = rand(0..100)
    p.low_stock_threshold = rand(1..10)
    p.category = child_categories.sample
    p.weight = rand(0.1..5.0).round(2)
    p.meta_title = "Meta Title for Seed Product #{i + 1000}"
    p.meta_description = "Meta description for Seed Product #{i + 1000}"
    p.flags = []
    p.brands = [brands.sample]
    p.featured = [true, false].sample
    p.free_installment_fee = free_fee
    p.sort_order = i + 1000
    p.status = %w[active inactive discontinued].sample
    p.stock_status = %w[in_stock out_of_stock low_stock].sample
    p.created_at = Faker::Date.backward(days: 90)
    p.product_tags = sample_tags.sample(rand(0..3))
    p.product_attributes = {
      "Material" => ["Cotton", "Polyester", "Leather", "Metal", "Plastic"].sample,
      "Color" => ["Black", "White", "Red", "Blue", "Green"].sample,
      "Size" => ["S", "M", "L", "XL"].sample,
      "Manufacturer" => Faker::Company.name
    }
  end
  product.product_variants.first.update!(original_price: original_price, current_price: current_price) if product.product_variants.any?
  products_created += 1
end

all_products = Product.all

# Assign collections to products
puts 'Assigning collections to products...'
collections.each do |collection|
  products_to_collect = all_products.sample(10)
  collection.products << products_to_collect unless products_to_collect.empty?
end

puts "\n" + "="*60
puts "Products Seeding Complete!"
puts "="*60
puts "✓ Created: #{brands_created} brands"
puts "✓ Created: #{collections_created} collections"
puts "✓ Created: #{products_created} products"
puts "✓ Images attached: #{images_attached}"
