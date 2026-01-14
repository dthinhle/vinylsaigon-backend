# WordPress to Baka Backend Migration Guide

This guide documents the WordPress/WooCommerce data migration services implemented for the Baka Backend system.

## Overview

The migration system consists of several specialized services that handle different aspects of the WordPress data import:

- **DataCleaner**: Cleans HTML content and converts URLs
- **MetaDataParser**: Extracts structured data from WordPress meta_data fields
- **BrandDetector**: Identifies and creates brand entries from product tags
- **CategoryMigrator**: Maps and migrates WordPress categories
- **ProductMigrator**: Main product migration service
- **WordpressMigrationJob**: Background job that orchestrates the entire migration

## Architecture

```
WordpressMigrationJob
  ├── CategoryMigrator
  │   └── Creates Category records with proper parent/child relationships
  │
  └── ProductMigrator
      ├── DataCleaner (HTML processing)
      ├── MetaDataParser (meta_data extraction)
      ├── BrandDetector (brand identification)
      └── Creates Product + ProductVariant + relationships
```

## Usage

### Running the Migration

```ruby
# Load JSON data from your WordPress export
categories_json = File.read('tmp/categories.json')
products_json = File.read('tmp/products.json')

# Option 1: Run synchronously
result = WordpressMigrationJob.new.perform(
  categories_json: categories_json,
  products_json: products_json
)

# Option 2: Run as background job
WordpressMigrationJob.perform_later(
  categories_json: categories_json,
  products_json: products_json
)
```

### Result Structure

```ruby
{
  success: true/false,
  started_at: Time,
  completed_at: Time,
  categories: {
    success: true,
    errors: [],
    migrated_count: 4,
    mapping: { 15 => 1, 16 => 2, ... }  # wp_id => category_id
  },
  products: {
    success: true,
    errors: [],
    warnings: ["Product X already exists", ...],
    migrated_count: 10,
    migrated_products: [
      { wp_id: 12345, product_id: 1, sku: 'NOBLE-FOKUS', name: '...' },
      ...
    ]
  }
}
```

## Data Mapping

### Category Mapping

WordPress categories are mapped to the new system according to CATEGORY_MAPPING constant:

```ruby
'headphone' / 'tai-nghe' => 'Tai nghe' (root)
'dac-amp' / 'dac/amp' => 'DAC/AMP' (root)
'analog-vinyl' / 'dap' => 'Nguồn phát' (root, merged)
'speaker' / 'loa' => 'Loa' (root)
'home-studio' => 'Home Studio' (root)
'phu-kien' => 'Phụ kiện' (root)
```

### Product Field Mapping

| WordPress Field | New System Field | Notes |
|----------------|------------------|-------|
| `slug` | `sku` | Generated as `slug.upcase` |
| `description` | `description` | HTML cleaned, URLs converted |
| `short_description` | `short_description` | Max 500 chars, auto-generated if empty |
| `status` ('publish') | `status` ('active') | Enum mapping |
| `stock_status` | `stock_status` + `stock_quantity` | See stock mapping below |
| `meta_data` | `product_attributes` | JSONB with parsed structure |

### Stock Status Mapping

```ruby
'instock' + manage_stock=false => stock_quantity=99, stock_status='in_stock'
'instock' + manage_stock=true  => use actual stock_quantity
'outofstock'                   => stock_quantity=0, stock_status='out_of_stock'
'onbackorder'                  => flags << 'backorder', stock_status='in_stock'
```

### Meta Data Extraction

```ruby
'bao_hanh'              => product_attributes['bao_hanh']
'qua_tang'              => gift_content
'sp_sap_ve' (yes)       => flags << 'arrive_soon'
'_yoast_wpseo_title'    => meta_title
'_yoast_wpseo_metadesc' => meta_description
'block_thong_tin_*'     => Parsed into structured product_attributes
```

## Testing

```bash
# Run all migration tests
bundle exec rspec spec/services/wordpress_migration/
bundle exec rspec spec/jobs/wordpress_migration_job_spec.rb

# Run individual test files
bundle exec rspec spec/services/wordpress_migration/data_cleaner_spec.rb
bundle exec rspec spec/services/wordpress_migration/category_migrator_spec.rb
bundle exec rspec spec/services/wordpress_migration/product_migrator_spec.rb
```

Test fixtures are in `spec/fixtures/wordpress_migration/`. Replace with actual WordPress export data for production migration.

## Important Notes

1. **SKU Generation**: Uses `slug.upcase` (e.g., "noble-fokus" => "NOBLE-FOKUS")
2. **Duplicate Prevention**: Products with existing SKU are skipped with warning
3. **Simple Products**: Create a single "Default" variant
4. **Variable Products**: Currently create default variant only (variations need separate migration)
5. **Timestamps**: WordPress `date_created` and `date_modified` are preserved
6. **Brand Detection**: Uses KNOWN_BRANDS list for case-insensitive matching
7. **HTML Cleaning**: Converts vinylsaigon.vn URLs to relative paths

## Future Enhancements

- [ ] Image download and attachment
- [ ] Product variation migration
- [ ] Related products migration
- [ ] Product attribute (pa.json) migration for variant creation

See test files for detailed examples and expected behavior.
