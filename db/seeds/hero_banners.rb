puts 'Seeding hero banners...'

hero_banners_data = [
  {
    main_title: "Honkai: Star Rail Collection",
    sub_title: "New Arrivals",
    description: "Immerse yourself in the world of Honkai: Star Rail with our exclusive collection of high-quality merchandise. From limited edition figures to iconic accessories, discover pieces that bring your favorite characters to life.",
    short_description: "Premium collectibles from the hit game Honkai: Star Rail",
    image_name: "banner-vinylsaigon-1.png"
  },
  {
    main_title: "Summer Gaming Festival",
    sub_title: "Special Event",
    description: "Beat the heat with our summer gaming collection! Featuring limited-time offers on gaming merchandise, collectibles, and exclusive items from your favorite franchises. Don't miss out on these seasonal specials!",
    short_description: "Exclusive summer deals on gaming merchandise",
    image_name: "banner-vinylsaigon-2.png"
  },
  {
    main_title: "Anime Essentials",
    sub_title: "Featured Collection",
    description: "Discover our curated selection of must-have anime merchandise. From classic series to the latest hits, find authentic collectibles, apparel, and accessories that celebrate your favorite anime moments.",
    short_description: "Essential items for anime enthusiasts",
    image_name: "banner-vinylsaigon-3.png"
  },
  {
    main_title: "Genshin Impact Collection",
    sub_title: "Popular Items",
    description: "Explore our extensive collection of Genshin Impact merchandise. Find high-quality figures, accessories, and collectibles featuring your favorite characters from Teyvat.",
    short_description: "Official Genshin Impact merchandise collection",
    image_name: "banner-vinylsaigon-4.png"
  },
  {
    main_title: "Limited Edition Figures",
    sub_title: "Exclusive Items",
    description: "Don't miss out on our exclusive collection of limited edition anime figures. Each piece is carefully crafted with attention to detail, making them perfect for serious collectors.",
    short_description: "Exclusive limited edition anime figures",
    image_name: "banner-vinylsaigon-5.png"
  },
  {
    main_title: "Anime Accessories",
    sub_title: "Best Sellers",
    description: "Complete your collection with our premium anime accessories. From keychains to phone cases, find the perfect items to show your love for your favorite series.",
    short_description: "Premium anime accessories and collectibles",
    image_name: "banner-vinylsaigon-6.png"
  },
]

# Clear existing banners
HeroBanner.destroy_all

banners_created = 0
images_attached = 0

hero_banners_data.each do |banner_data|
  banner = HeroBanner.new(banner_data.except(:image_name))

  # Attach image from seeds/files folder
  image_path = Rails.root.join("db", "seeds", "files", banner_data[:image_name])
  if File.exist?(image_path)
    banner.image.attach(
      io: File.open(image_path),
      filename: banner_data[:image_name],
      content_type: "image/png"
    )
    images_attached += 1
    puts "  ✓ Created banner '#{banner.main_title}' with image"
  else
    puts "  ⚠ Created banner '#{banner.main_title}' without image (file not found)"
  end

  banner.save!
  banners_created += 1
end

puts "\n" + "="*60
puts "Hero Banners Seeding Complete!"
puts "="*60
puts "✓ Created: #{banners_created} hero banners"
puts "✓ Images attached: #{images_attached}"
