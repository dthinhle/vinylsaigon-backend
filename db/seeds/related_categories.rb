puts 'Seeding related categories...'

# Clear existing related categories
RelatedCategory.destroy_all

# Get all categories as a hash for quick lookup
categories_by_title = Category.all.index_by(&:title)

puts "Found #{categories_by_title.count} total categories"

relationships_created = 0
skipped_relationships = 0

# Create relationships based on realistic audio equipment compatibility
puts 'Creating realistic category relationships...'

CATEGORY_RELATIONSHIPS.each do |source_category_name, related_categories|
  source_category = categories_by_title[source_category_name]

  unless source_category
    puts "Warning: Source category '#{source_category_name}' not found"
    next
  end

  related_categories.each do |relationship|
    target_category_name = relationship[:related_category]
    weight = relationship[:weight]

    target_category = categories_by_title[target_category_name]

    unless target_category
      puts "Warning: Target category '#{target_category_name}' not found"
      next
    end

    # Skip if relationship already exists
    if RelatedCategory.exists?(category: source_category, related_category: target_category)
      skipped_relationships += 1
      next
    end

    begin
      RelatedCategory.create_bidirectional!(source_category, target_category, weight)
      relationships_created += 2 # bidirectional creates 2 records
      puts "  ✓ #{source_category.title} ↔ #{target_category.title} (weight: #{weight})"
    rescue ActiveRecord::RecordInvalid => e
      puts "  ✗ Failed: #{source_category.title} ↔ #{target_category.title}: #{e.message}"
      skipped_relationships += 1
    end
  end
end

puts "\n" + "="*60
puts "Related Categories Seeding Complete!"
puts "="*60
puts "✓ Created: #{relationships_created} relationship records"
puts "✓ Unique pairs: #{RelatedCategory.count / 2}"
puts "⚠ Skipped: #{skipped_relationships} (duplicates or errors)"

# Show examples by category type
puts "\nSample relationships by category:"
puts "-" * 40

['Tai nghe', 'DAC/AMP', 'In-Ear', 'Portable DAC/AMP'].each do |category_name|
  category = categories_by_title[category_name]
  next unless category

  puts "\n#{category_name}:"
  relations = RelatedCategory.includes(:related_category)
                            .where(category: category)
                            .order(weight: :desc)
                            .limit(3)

  relations.each do |relation|
    puts "  → #{relation.related_category.title} (weight: #{relation.weight})"
  end
end
