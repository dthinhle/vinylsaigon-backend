puts 'Seeding promotions...'

ids = Product.limit(4).ids
# Seed promotions for admin UI (idempotent)
promotions = [
  {
    title: 'Autumn Sale — 10% Off',
    code: 'SEED-AUTUMN10',
    starts_at: Time.current - 7.days,
    ends_at: Time.current + 7.days,
    discount_type: 'percentage',
    discount_value: 10.0,
    active: true,
    stackable: true, # Can be combined with other stackable promotions
    usage_limit: 100,
    metadata: { note: 'Seeded active, stackable promotion' }
  },
  {
    title: 'October Voucher — $20 Off',
    code: 'SEED-FIXED20',
    starts_at: Time.current + 5.days,
    ends_at: Time.current + 30.days,
    discount_type: 'fixed',
    discount_value: 200_000,
    active: false,
    stackable: false,
    usage_limit: 50,
    metadata: { note: 'Seeded upcoming fixed discount' }
  },
  {
    title: 'Summer Clearance — 5% Off (expired)',
    code: 'SEED-EXPIRED5',
    starts_at: Time.current - 30.days,
    ends_at: Time.current + 15.seconds, # Ends shortly after seeding
    discount_type: 'percentage',
    discount_value: 5.0,
    active: false,
    stackable: false,
    usage_limit: 1000,
    metadata: { note: 'Seeded expired promotion' }
  },
  {
    title: 'Loyalty Bonus - 50k Off',
    code: 'SEED-LOYAL50K',
    starts_at: Time.current,
    ends_at: Time.current + 1.year,
    discount_type: 'fixed',
    discount_value: 50000, # 50,000 VND
    active: true,
    stackable: true,
    usage_limit: nil,
    metadata: { note: 'Simple stackable loyalty bonus' }
  },
  {
    title: 'Flash Sale - 25% Off',
    code: 'SEED-FLASH25',
    starts_at: Time.current,
    ends_at: Time.current + 2.days,
    discount_type: 'percentage',
    discount_value: 25,
    active: true,
    stackable: false,
    usage_limit: 200,
    metadata: { note: 'A powerful, non-stackable promo' }
  },
  {
    title: 'Free Shipping Sim',
    code: 'SEED-FREESHIP',
    starts_at: Time.current,
    ends_at: Time.current + 1.year,
    discount_type: 'fixed',
    discount_value: 30000, # Simulate a 30k VND shipping fee waiver
    active: true,
    stackable: true,
    usage_limit: nil,
    metadata: { note: 'A stackable promo to simulate free shipping' }
  },
  {
    title: 'Bundle Deal - Coffee Set',
    code: 'SEED-BUNDLE1',
    starts_at: Time.current,
    ends_at: Time.current + 30.days,
    discount_type: 'bundle',
    discount_value: 50000, # 50k VND off the bundle
    active: true,
    stackable: false,
    usage_limit: 50,
    product_bundles_attributes: [
      { product_id: ids[0], quantity: 1 },
      { product_id: ids[1], quantity: 1 },
    ],
    metadata: { note: 'Bundle promotion for coffee set' }
  },
  {
    title: 'Tech Gadget Bundle',
    code: 'SEED-BUNDLE2',
    starts_at: Time.current + 10.days,
    ends_at: Time.current + 60.days,
    discount_type: 'bundle',
    discount_value: 100000, # 100k VND off
    active: false,
    stackable: true,
    usage_limit: 20,
    product_bundles_attributes: [
      { product_id: ids[2], quantity: 1 },
      { product_id: ids[3], quantity: 2 },
    ],
    metadata: { note: 'Upcoming bundle for tech gadgets' }
  },
]

promotions_created = 0

promotions.each do |attrs|
  promotion = Promotion.find_or_create_by(code: attrs[:code]) do |p|
    p.assign_attributes(attrs.except(:code))
  end
  if promotion.persisted? && promotion.created_at == promotion.updated_at
    promotions_created += 1
    puts "  ✓ Created promotion '#{attrs[:title]}' (#{attrs[:code]})"
  else
    puts "  ⚠ Promotion '#{attrs[:title]}' (#{attrs[:code]}) already exists"
  end
end

puts "\n" + "="*60
puts "Promotions Seeding Complete!"
puts "="*60
puts "✓ Created: #{promotions_created} promotions"
