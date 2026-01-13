# frozen_string_literal: true

module WordpressMigration
  class BrandDetector
    BRANDS_CSV_PATH = Rails.root.join('db', 'seeds', 'data', 'all_brands.csv')
    PRODUCT_BRANDS_CSV_PATH = Rails.root.join('db', 'seeds', 'data', 'product_brands.csv')

    attr_reader :errors

    # Cache for product => brand name mappings across all instances
    @product_brand_mappings = nil

    class << self
      def product_brand_mappings
        @product_brand_mappings ||= begin
          return {} unless File.exist?(PRODUCT_BRANDS_CSV_PATH)

          csv_rows = CSV.read(PRODUCT_BRANDS_CSV_PATH)
          unless csv_rows.empty?
            csv_rows.to_h { |wp_id, *_, brand_name, _| [wp_id.to_s, brand_name] }
          else
            {}
          end
        rescue StandardError => e
          Rails.logger.error("Failed to load product-brand CSV: #{e.message}")
          {}
        end
      end

      # Allow tests or callers to refresh the in-memory product brand mappings
      def reset_product_brand_mappings!
        @product_brand_mappings = nil
      end
    end

    def initialize
      @errors = []
      @brand_cache = {}
      @csv_brands = load_brands_from_csv
      self.class.product_brand_mappings
    end

    def detect_and_create(meta_data)
      return [] if meta_data.blank?

      brand_id = extract_brand_id(meta_data)
      return [] if brand_id.blank?

      brand = find_or_create_brand_by_id(brand_id)
      brand ? [brand] : []
    end

    # Expose a class-level product => brand name mapping for use by callers
    def product_brand_mappings
      self.class.product_brand_mappings
    end

    # Helper to get brand name for a given WP product ID from the product-brand CSV mapping
    def product_brand_name_for(wp_id)
      return nil if wp_id.blank?
      product_brand_mappings[wp_id.to_s]
    end

    # Convenience: find or create a Brand by product-brand CSV mapping. Returns Brand or nil.
    def brand_for_product(wp_id)
      name = product_brand_name_for(wp_id)
      return nil if name.blank?
      Brand.find_or_create_by(name: CGI.unescapeHTML(name).strip)
    rescue StandardError => e
      @errors << "Failed to find or create brand for product ID '#{wp_id}': #{e.message}"
      nil
    end

    # Filter tags to exclude ones belonging to detected brands.
    def filter_non_brand_tags(wp_tags)
      return [] if wp_tags.blank?

      tags = wp_tags.is_a?(Array) ? wp_tags : [wp_tags]

      # Build sets of known brand slugs and names from loaded CSV (if any)
      brand_slugs = (@csv_brands || {}).values.map { |b| b[:slug].to_s.downcase }
      brand_names = (@csv_brands || {}).values.map { |b| b[:name].to_s.downcase }

      tags.reject do |tag|
        tag_name = tag.is_a?(Hash) ? tag['name'].to_s.downcase : tag.to_s.downcase
        tag_slug = tag.is_a?(Hash) ? tag['slug'].to_s.downcase : nil
        (tag_slug && brand_slugs.include?(tag_slug)) || brand_names.include?(tag_name)
      end
    end

    private

    def extract_brand_id(meta_data)
      return nil if meta_data.blank?

      meta_array = meta_data.is_a?(Array) ? meta_data : [meta_data]

      brand_meta = meta_array.find { |m| m.is_a?(Hash) && m['key'] == '_yoast_wpseo_primary_brand' }
      brand_meta&.dig('value')
    end

    # TODO: Implement SQL query to fetch and store the results instead of using CSV
    # for migrations
    # SQL to fetch brands:
    # SELECT
    #     prod.ID wp_id,
    #     prod.post_title product_name,
    #     term.term_id,
    #     term.name brand_name,
    #     term.slug brand_slug
    # FROM
    # 2uhNN_term_relationships pm
    # JOIN 2uhNN_posts prod ON prod.ID = pm.object_id
    # JOIN 2uhNN_terms term ON term.term_id = pm.term_taxonomy_id
    #    WHERE
    # pm.term_taxonomy_id IN (
    #    SELECT
    #      term_taxonomy_id
    #    FROM
    #      2uhNN_term_taxonomy
    #    WHERE
    #      term_id IN (
    #        SELECT
    #          term_id
    #        FROM
    #          2uhNN_term_taxonomy
    #        WHERE
    #          taxonomy = 'brand'
    #      )
    # );
    def load_brands_from_csv
      return {} unless File.exist?(BRANDS_CSV_PATH)

      brands = {}
      CSV.foreach(BRANDS_CSV_PATH, headers: true) do |row|
        brands[row['id']] = { name: row['name'], slug: row['slug'] }
      end
      brands
    rescue StandardError => e
      @errors << "Failed to load brands from CSV: #{e.message}"
      {}
    end

    def find_or_create_brand_by_id(brand_id)
      brand_id_str = brand_id.to_s
      return @brand_cache[brand_id_str] if @brand_cache.key?(brand_id_str)

      csv_brand = @csv_brands[brand_id_str]
      return nil unless csv_brand

      brand = Brand.find_by(slug: csv_brand[:slug])

      if brand.nil?
        brand = Brand.create!(
          name: csv_brand[:name],
          slug: csv_brand[:slug]
        )
      end

      @brand_cache[brand_id_str] = brand
      brand
    rescue StandardError => e
      @errors << "Failed to create brand ID '#{brand_id}' (#{csv_brand[:name]}): #{e.message}"
      nil
    end
  end
end
