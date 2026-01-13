# WordPress Data Migration - Quick Start

## Overview

This implementation provides a complete solution for migrating WordPress/WooCommerce data to the Baka Backend system.

## What's Included

### Services (`app/services/wordpress_migration/`)
- `DataCleaner` - HTML cleaning and URL conversion
- `MetaDataParser` - Extract structured data from WordPress meta_data
- `BrandDetector` - Identify brands from tags
- `CategoryMigrator` - Migrate categories with proper mapping
- `ProductMigrator` - Complete product migration logic

### Background Job (`app/jobs/`)
- `WordpressMigrationJob` - Orchestrates the full migration process

### Tests (`spec/`)
- Comprehensive RSpec tests for all services
- Test fixtures in `spec/fixtures/wordpress_migration/`
- Integration tests for end-to-end migration

## Quick Start

### 1. Prepare Your Data

Place your WordPress export JSON files in the `tmp/` directory:
- `tmp/categories.json` - WordPress categories export
- `tmp/products.json` - WordPress products export

### 2. Run Tests

```bash
# Run all migration tests
bundle exec rspec spec/services/wordpress_migration/
bundle exec rspec spec/jobs/wordpress_migration_job_spec.rb

# Run specific test
bundle exec rspec spec/services/wordpress_migration/product_migrator_spec.rb
```

### 3. Execute Migration

```ruby
# In Rails console
categories_json = File.read(Rails.root.join('tmp/categories.json'))
products_json = File.read(Rails.root.join('tmp/products.json'))

# Run migration
result = WordpressMigrationJob.new.perform(
  categories_json: categories_json,
  products_json: products_json
)

# Check results
puts "Success: #{result[:success]}"
puts "Categories migrated: #{result[:categories][:migrated_count]}"
puts "Products migrated: #{result[:products][:migrated_count]}"
puts "Errors: #{result[:categories][:errors] + result[:products][:errors]}"
puts "Warnings: #{result[:products][:warnings]}"
```

### 4. Run as Background Job

```ruby
# Enqueue the job
WordpressMigrationJob.perform_later(
  categories_json: categories_json,
  products_json: products_json
)
```

## Important Notes

1. **Test Data**: The fixtures in `spec/fixtures/wordpress_migration/` are samples. Replace with actual WordPress export for production.

2. **Category Matching**: Child categories are matched based on content. Ensure your categories.json has the correct parent relationships.

3. **SKU Generation**: Products without SKU will have one generated from their slug (UPPERCASE).

4. **Stock Quantities**: Non-managed stock products default to quantity 99.

5. **Brand Detection**: Brands are identified from tags using the KNOWN_BRANDS list. Add your brands to `brand_detector.rb` if needed.

## Data Mapping Highlights

- **Categories**: WordPress parent categories → root categories, children → children
- **Products**: Simple → 1 variant, Variable → default variant (variations need separate migration)
- **Prices**: regular_price → original_price, sale_price → current_price
- **Meta Data**: Extracted to product_attributes JSONB (warranty, gifts, SEO, technical specs)
- **Brands**: Auto-detected from tags, remaining tags become ProductTags
- **HTML**: Cleaned and URLs converted to relative paths

## Troubleshooting

If tests fail:
1. Check database is set up: `rails db:test:prepare`
2. Verify fixtures exist in `spec/fixtures/wordpress_migration/`
3. Check Rails console for detailed error messages

For detailed documentation, see `docs/WORDPRESS_MIGRATION.md`.

## Next Steps

After successful migration:
- [ ] Verify data in Rails console
- [ ] Check product variants were created correctly
- [ ] Validate category hierarchy
- [ ] Review brands and tags
- [ ] Handle any warnings or errors from migration result
- [ ] Consider implementing image download (future enhancement)
- [ ] Implement variation migration for variable products (future enhancement)
