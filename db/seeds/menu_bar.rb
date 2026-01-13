
puts 'Seeding menu bar...'

# Clear existing data
MenuBar::Item.delete_all
MenuBar::Section.delete_all
ActiveRecord::Base.connection.reset_sequence!(MenuBar::Item.table_name, 'id')
ActiveRecord::Base.connection.reset_sequence!(MenuBar::Section.table_name, 'id')

sections_created = 0
items_created = 0
sub_items_created = 0

# Create sections
left_section = MenuBar::Section.create!(section_type: 'left')
main_section = MenuBar::Section.create!(section_type: 'main')
sections_created += 3
puts "  ✓ Created #{sections_created} menu sections"

# Position counters for each section
left_position = 1
main_position = 1

items_created += 1

# Left Section Items
left_section.items.create!(
  item_type: 'link',
  label: 'Tất cả sản phẩm',
  link: '/san-pham',
  position: left_position
)
left_position += 1
items_created += 1

featured = left_section.items.create!(
  item_type: 'header',
  label: 'Nổi bật',
  position: left_position
)
left_position += 1
items_created += 1

featured.sub_items.create!([
  {
    item_type: 'link',
    label: 'Hàng mới về',
    link: '/bo-suu-tap/hang-moi-ve',
    section: left_section,
    position: 1
  },
  {
    item_type: 'link',
    label: 'Khuyến mãi',
    link: '/bo-suu-tap/khuyen-mai',
    section: left_section,
    position: 2
  },
])
sub_items_created += 2

collections = left_section.items.create!(
  item_type: 'header',
  label: 'Bộ sưu tập',
  position: left_position
)
left_position += 1
items_created += 1

collections.sub_items.create!(
  item_type: 'link',
  label: 'B&O 2025',
  link: '/bo-suu-tap/beo-2025',
  section: left_section,
  position: 1
)
sub_items_created += 1

# Build menu from categories
puts 'Building menu from categories...'
Category.where(is_root: true).each do |parent_category|
  parent_item = main_section.items.create!(
    item_type: 'link',
    label: parent_category.title,
    link: "/danh-muc/#{parent_category.slug}",
    position: main_position
  )
  main_position += 1
  items_created += 1

  sub_items_data = parent_category.children.map.with_index(1) do |child_category, idx|
    {
      item_type: 'link',
      label: child_category.title,
      link: "/danh-muc/#{child_category.slug}",
      section: main_section,
      position: idx
    }
  end

  parent_item.sub_items.create!(sub_items_data) if sub_items_data.any?
  sub_items_created += sub_items_data.size
end

puts "\n" + "="*60
puts "Menu Bar Seeding Complete!"
puts "="*60
puts "✓ Created: #{sections_created} sections"
puts "✓ Created: #{items_created} menu items"
puts "✓ Created: #{sub_items_created} sub-items"
