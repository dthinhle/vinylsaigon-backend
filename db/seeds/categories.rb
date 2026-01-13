puts 'Seeding categories...'

# Clear existing categories and their dependencies
# First clear products associated with categories, then categories
Product.update_all(category_id: nil) if ActiveRecord::Base.connection.column_exists?(:products, :category_id)
Category.destroy_all

image_paths = Dir.glob(Rails.root.join('db', 'seeds', 'files', '*.{webp}')).filter { |n| n.include?('brand-cover') }

categories_created = 0
parent_categories_created = 0
child_categories_created = 0
images_attached = 0

DEFAULT_CATEGORIES.each do |category_data|
  # Extract image name and children data
  image_name = category_data[:image]
  children_data = category_data[:children]

  # Prepare category attributes for the parent
  parent_attributes = {
    title: category_data[:name],
    description: category_data[:description],
    slug: category_data[:slug] || Slugify.convert(category_data[:name]),
    is_root: true,
    button_text: category_data[:button_text]
  }

  # Find image path and create blob if it exists
  image_path = Rails.root.join('db', 'seeds', 'files', image_name)
  if File.exist?(image_path)
    parent_attributes[:image] = {
      io: File.open(image_path),
      filename: image_name,
      content_type: 'image/jpeg'
    }
  end

  # Create the parent category
  parent_category = Category.create!(parent_attributes)
  parent_categories_created += 1
  categories_created += 1

  if File.exist?(image_path)
    puts "  ✓ Created parent category '#{category_data[:name]}' with image"
  else
    puts "  ⚠ Created parent category '#{category_data[:name]}' without image (file not found: #{image_path})"
  end

  # Create child categories
  children_data.each do |child_data|
    child_category = parent_category.children.create!(
      title: child_data[:name],
      slug: child_data[:slug] || Slugify.convert(child_data[:name]),
      description: Faker::Lorem.sentence(word_count: 5, random_words_to_add: 2)
    )
    child_categories_created += 1
    categories_created += 1

    image_path = image_paths.sample
    if image_path && File.exist?(image_path)
      child_category.image.attach(
        io: File.open(image_path),
        filename: File.basename(image_path),
        content_type: 'image/webp'
      )
      images_attached += 1
    end
  end
end

puts "\n" + "="*60
puts "Categories Seeding Complete!"
puts "="*60
puts "✓ Created: #{categories_created} total categories"
puts "✓ Parent categories: #{parent_categories_created}"
puts "✓ Child categories: #{child_categories_created}"
puts "✓ Images attached: #{images_attached}"
