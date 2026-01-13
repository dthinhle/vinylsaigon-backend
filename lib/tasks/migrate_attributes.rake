# frozen_string_literal: true

namespace :db do
  desc 'Migrate product_attributes and variant_attributes from old hash format to new array format'
  task migrate_attributes_format: :environment do
    puts 'Starting attributes format migration...'

    product_count = 0
    product_converted = 0
    product_skipped = 0

    variant_count = 0
    variant_converted = 0
    variant_skipped = 0

    # Migrate Products
    puts "\nMigrating Product.product_attributes..."
    Product.find_in_batches(batch_size: 100) do |products|
      products.each do |product|
        product_count += 1
        attrs = product.product_attributes

        if attrs.blank?
          product_skipped += 1
          next
        end

        # Check if already in new format
        if attrs.is_a?(Hash) && attrs.key?('attributes') && attrs['attributes'].is_a?(Array)
          product_skipped += 1
          next
        end

        # Convert old format to new
        if attrs.is_a?(Hash)
          new_attrs = { 'attributes' => attrs.map { |k, v| { 'name' => k, 'value' => v } } }
          product.update_column(:product_attributes, new_attrs)
          product_converted += 1
          puts "  Converted Product ##{product.id} (#{attrs.keys.count} attributes)"
        end
      end
    end

    # Migrate ProductVariants
    puts "\nMigrating ProductVariant.variant_attributes..."
    ProductVariant.find_in_batches(batch_size: 100) do |variants|
      variants.each do |variant|
        variant_count += 1
        attrs = variant.variant_attributes

        if attrs.blank?
          variant_skipped += 1
          next
        end

        # Check if already in new format
        if attrs.is_a?(Hash) && attrs.key?('attributes') && attrs['attributes'].is_a?(Array)
          variant_skipped += 1
          next
        end

        # Convert old format to new
        if attrs.is_a?(Hash)
          new_attrs = { 'attributes' => attrs.map { |k, v| { 'name' => k, 'value' => v } } }
          variant.update_column(:variant_attributes, new_attrs)
          variant_converted += 1
          puts "  Converted ProductVariant ##{variant.id} (#{attrs.keys.count} attributes)"
        end
      end
    end

    puts "\n" + '=' * 60
    puts 'Migration Summary:'
    puts '=' * 60
    puts 'Products:'
    puts "  Total processed: #{product_count}"
    puts "  Converted: #{product_converted}"
    puts "  Skipped: #{product_skipped}"
    puts "\nProductVariants:"
    puts "  Total processed: #{variant_count}"
    puts "  Converted: #{variant_converted}"
    puts "  Skipped: #{variant_skipped}"
    puts '=' * 60
  end

  desc 'Rollback attributes format migration (restore from new format to old format)'
  task rollback_attributes_format: :environment do
    puts 'WARNING: This will convert attributes from new array format back to old hash format'
    puts 'Press Ctrl+C to cancel, or press Enter to continue...'
    STDIN.gets

    product_count = 0
    product_converted = 0

    variant_count = 0
    variant_converted = 0

    # Rollback Products
    puts "\nRolling back Product.product_attributes..."
    Product.find_in_batches(batch_size: 100) do |products|
      products.each do |product|
        product_count += 1
        attrs = product.product_attributes

        next if attrs.blank?

        # Check if in new format
        if attrs.is_a?(Hash) && attrs.key?('attributes') && attrs['attributes'].is_a?(Array)
          # Convert back to old format
          old_attrs = {}
          attrs['attributes'].each do |attr|
            old_attrs[attr['name']] = attr['value'] if attr['name'].present?
          end
          product.update_column(:product_attributes, old_attrs)
          product_converted += 1
          puts "  Rolled back Product ##{product.id}"
        end
      end
    end

    # Rollback ProductVariants
    puts "\nRolling back ProductVariant.variant_attributes..."
    ProductVariant.find_in_batches(batch_size: 100) do |variants|
      variants.each do |variant|
        variant_count += 1
        attrs = variant.variant_attributes

        next if attrs.blank?

        # Check if in new format
        if attrs.is_a?(Hash) && attrs.key?('attributes') && attrs['attributes'].is_a?(Array)
          # Convert back to old format
          old_attrs = {}
          attrs['attributes'].each do |attr|
            old_attrs[attr['name']] = attr['value'] if attr['name'].present?
          end
          variant.update_column(:variant_attributes, old_attrs)
          variant_converted += 1
          puts "  Rolled back ProductVariant ##{variant.id}"
        end
      end
    end

    puts "\n" + '=' * 60
    puts 'Rollback Summary:'
    puts '=' * 60
    puts "Products rolled back: #{product_converted}/#{product_count}"
    puts "Variants rolled back: #{variant_converted}/#{variant_count}"
    puts '=' * 60
  end
end
