puts 'Seeding store data...'

stores_created = 0
addresses_created = 0

store = Store.create!(STORE_CONFIG.slice(:name, :instagram_url, :youtube_url, :facebook_url))
stores_created += 1
puts "  ✓ Created store '#{store.name}'"

puts 'Creating store addresses...'

Address.create!(
  addressable: store,
  address: '14 Nguyễn Văn Giai',
  ward: 'P. Đa Kao',
  district: 'Q.1',
  city: 'TP. Hồ Chí Minh',
  map_url: 'https://goo.gl/maps/ZdxraaA4LawbRose6',
  phone_numbers: [
    '(028) 38 202 909',
    '0914 345 357',
  ],
  is_head_address: true
)
addresses_created += 1
puts "  ✓ Created head address"

Address.create!(
  addressable: store,
  address: '6B Đinh Bộ Lĩnh',
  ward: 'P.24',
  district: 'Q. Bình Thạnh',
  city: 'TP. Hồ Chí Minh',
  map_url: 'https://goo.gl/maps/GEKrLoC91cbwkrbdA',
  phone_numbers: [
    '(028) 62 656 596',
    '0914 345 357',
  ],
  is_head_address: false
)
addresses_created += 1
puts "  ✓ Created branch address"

puts "\n" + "="*60
puts "Store Seeding Complete!"
puts "="*60
puts "✓ Created: #{stores_created} store"
puts "✓ Created: #{addresses_created} addresses"
