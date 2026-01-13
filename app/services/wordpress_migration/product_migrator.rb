# frozen_string_literal: true

module WordpressMigration
  # Main service for migrating WordPress products to new system
  class ProductMigrator
    attr_reader :errors, :warnings, :migrated_products, :category_mapping

    def initialize(wp_products_json, category_mapping = {})
      @wp_products = parse_products(wp_products_json)
      @category_mapping = category_mapping
      @brand_detector = BrandDetector.new
      @errors = []
      @warnings = []
      @migrated_products = []
    end

    def migrate!
      @wp_products.each do |wp_product|
        Rails.logger.info("Migrating product: #{wp_product['name']} (ID: #{wp_product['id']})")
        migrate_product(wp_product)
      end

      {
        success: errors.empty?,
        errors: errors,
        warnings: warnings,
        migrated_count: migrated_products.count,
        migrated_products: migrated_products
      }
    end

    private

    def parse_products(json_data)
      return [] if json_data.blank?

      case json_data
      when String
        JSON.parse(json_data)
      when Array
        json_data
      else
        []
      end
    rescue JSON::ParserError => e
      @errors << "Failed to parse products JSON: #{e.message}"
      []
    end

    def migrate_product(wp_product)
      wp_id = wp_product['id']
      wp_product['name'] = CGI.unescapeHTML(wp_product['name'].strip)

      return unless wp_product['name'].present? && wp_product['status'] == 'publish'

      ActiveRecord::Base.transaction do
        # Parse meta data
        meta_parser = MetaDataParser.new(wp_product['meta_data'])
        meta_parser.parse!

        # Clean HTML description
        description = DataCleaner.clean_html(wp_product['description'])

        short_description = DataCleaner.clean_html(wp_product['short_description'])

        # Map category
        category = map_category(wp_product)
        @warnings << "Product '#{wp_product['name']}' (WP ID: #{wp_id}) has no category, wp_product categories value is #{wp_product['categories'].map { it['name'] }}." unless category

        # Detect brands and filter tags
        brands = @brand_detector.brand_for_product(wp_product['id'])
        brands = [brands] if brands
        brands ||= @brand_detector.detect_and_create(wp_product['tags'])

        @warnings << "Product '#{wp_product['name']}' (WP ID: #{wp_id}) has no brands, wp_product brands value is #{wp_product['meta_data'].find { it['name'] == '_yoast_wpseo_primary_brand' }.inspect}." unless brands.any?

        remaining_tags = @brand_detector.filter_non_brand_tags(wp_product['tags'])

        # Determine stock status and quantity
        stock_status, stock_quantity = determine_stock_status(wp_product)

        # Build flags
        flags = build_flags(wp_product, meta_parser)

        # Create product
        sku = generate_sku(wp_product['slug'])
        if sku.blank?
          @warnings << "Product '#{wp_product['name']}' (WP ID: #{wp_id}) has no slug; generating SKU from name."
          return
        end
        slug = generate_unique_product_slug(wp_product['slug'])

        product_attributes = meta_parser.product_attributes
        Rails.logger.debug("Product attributes for '#{wp_product['name']}': #{product_attributes.inspect}")

        product = Product.where(sku: sku).first_or_initialize

        meta_parser.youtube_ids.each do |video_id|
          description[:root][:children].prepend({
            "videoID": video_id,
            "type": 'youtube',
            "version": 1
          })
        end

        meta_title = meta_parser.meta_title
        if meta_title.present?
          meta_title.gsub!('%%title%%', wp_product['name'])
          meta_title.gsub!('%%page%%', '')
          meta_title.gsub!(/\s*\|\s*/, ' | ')
          meta_title.gsub!(/ +\%\%sep\%\% +/, ' - ')
        end

        product.assign_attributes(
          name: wp_product['name'],
          slug: slug,
          sku: sku,
          description: description,
          short_description: short_description,
          status: map_status(wp_product['status']),
          featured: wp_product['featured'] || false,
          category: category,
          stock_status: stock_status,
          stock_quantity: stock_quantity,
          weight: wp_product['weight'],
          flags: flags,
          product_tags: remaining_tags.map { |tag| tag.is_a?(Hash) ? tag['name'] : tag.to_s }.compact_blank,
          gift_content: meta_parser.gift_content || {},
          meta_title: meta_parser.meta_title,
          meta_description: meta_parser.meta_description,
          warranty_months: meta_parser.warranty,
          product_attributes:,
          created_at: wp_product['date_created'],
          updated_at: wp_product['date_modified'],

          legacy_wp_id: wp_id,
          legacy_attributes: legacy_product_attributes(wp_product)
        )
        product.save!

        # Associate brands
        product.brands = brands if brands.any?

        # Create variants based on product type
        if wp_product['type'] == 'variable'
          # Variable product - will be handled separately if variations data is provided
          create_default_variant(product, wp_product, stock_status)
          @warnings << "Variable product '#{product.name}' created with default variant. Variations need separate migration."
        else
          # Simple product - create single default variant
          create_default_variant(product, wp_product, stock_status)
        end

        @migrated_products << {
          wp_id: wp_id,
          product_id: product.id,
          sku: product.sku,
          name: product.name
        }
      end
    rescue StandardError => e
      @errors << "Failed to migrate product '#{wp_product['name']}' (WP ID: #{wp_id}): #{e.message}"
      Rails.logger.error("Product migration error: #{e.message}\n#{e.backtrace.join("\n")}")
    end

    def generate_sku(slug)
      slug.to_s.upcase.gsub('-', '-')
    end

    def generate_unique_product_slug(base_slug)
      slug = base_slug
      counter = 1

      while Product.exists?(slug: slug)
        slug = "#{base_slug}-#{counter}"
        counter += 1
      end

      slug
    end

    def map_category(wp_product)
      CategoryMapperService.determine_category(wp_product)
    end

    def determine_stock_status(wp_product)
      wp_stock_status = wp_product['stock_status']
      manage_stock = wp_product['manage_stock']
      stock_qty = wp_product['stock_quantity']

      case wp_stock_status
      when 'outofstock'
        ['out_of_stock', 0]
      when 'onbackorder'
        ['in_stock', stock_qty || 0]
      when 'instock'
        if manage_stock && stock_qty.present?
          ['in_stock', stock_qty]
        else
          ['in_stock', 99] # Default for non-managed stock
        end
      else
        ['in_stock', 0]
      end
    end

    def build_flags(wp_product, meta_parser)
      flags = []
      flags.concat(meta_parser.flags)
      flags << 'backorder' if wp_product['stock_status'] == 'onbackorder'
      flags.uniq
    end

    def legacy_product_attributes(wp_product)
      attributes = wp_product['attributes'] || []
      simplified_attrs = attributes.map do |attr|
        {
          name: attr['name'],
          options: attr['options']
        }
      end
      {
        attributes: simplified_attrs
      }
    end

    def map_status(wp_status)
      case wp_status
      when 'publish'
        'active'
      when 'draft', 'pending'
        'inactive'
      else
        'inactive'
      end
    end

    def create_default_variant(product, wp_product, stock_status)
      original_price = parse_price(wp_product['regular_price'] || wp_product['price'])
      current_price = parse_price(wp_product['sale_price'])

      variant = product.product_variants.first || product.product_variants.build
      variant.assign_attributes(
        name: 'Default',
        sku: product.sku,
        slug: product.slug || Slugify.convert(product.name, true),
        original_price: original_price,
        current_price: current_price,
        status: product.status,
        stock_quantity: product.stock_quantity
      )
      variant.save!

      images = wp_product['images'] || []
      images.shift if images.size >= 2 && images.first['src'] == images.second['src'] # Remove duplicate first image

      images.each_with_index do |img_data, index|
        img_url = img_data['src']
        next if img_url.blank?

        Rails.logger.debug { "Attaching image to variant '#{variant.name}' of product '#{product.name}': #{img_url}" }
        # TODO: Temporarily disable image migration
        # file_path = Rails.root.join('tmp', 'wp_migration', File.basename(URI.parse(img_url).path))
        # FileUtils.mkdir_p(File.dirname(file_path))
        # File.write(file_path, URI.open(img_url).read, binmode: true) unless File.exist?(file_path)

        # variant.images.attach(
        #   io: File.open(file_path),
        #   filename: File.basename(file_path),
        #   content_type: Marcel::MimeType.for(file_path)
        # )

        # File.unlink(file_path) if File.exist?(file_path)
      end

      variant
    end

    def parse_price(price_string)
      return nil if price_string.blank? || price_string.to_s == '0'

      price_string.to_s.gsub(/[^\d.]/, '').to_f
    end
  end
end
