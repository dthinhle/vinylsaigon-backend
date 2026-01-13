# frozen_string_literal: true

module WordpressMigration
  # Service for mapping and migrating WordPress categories
  class CategoryMigrator
    # Category mapping from old WordPress to new system
    CATEGORY_MAPPING = {
      'headphone' => 'Tai nghe',
      'tai-nghe' => 'Tai nghe',
      'dac-amp' => 'DAC/AMP',
      'dac/amp' => 'DAC/AMP',
      'analog-vinyl' => 'Nguồn phát',
      'vinyl-analog' => 'Nguồn phát',
      'dap' => 'Nguồn phát',
      'speaker' => 'Loa',
      'loa' => 'Loa',
      'home-studio' => 'Home Studio',
      'phu-kien' => 'Phụ kiện'
    }.freeze

    attr_reader :wp_categories, :errors, :mapping

    def initialize(wp_categories_json)
      @wp_categories = parse_categories(wp_categories_json)
      @errors = []
      @mapping = {} # wp_id => new_category_id
    end

    def migrate!
      ActiveRecord::Base.transaction do
        migrate_root_categories
        migrate_child_categories
      end

      {
        success: errors.empty?,
        errors: errors,
        mapping: mapping
      }
    rescue StandardError => e
      @errors << "Transaction failed: #{e.message}"
      { success: false, errors: errors, mapping: {} }
    end

    private

    def parse_categories(json_data)
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
      @errors << "Failed to parse categories JSON: #{e.message}"
      []
    end

    def migrate_root_categories
      root_categories = wp_categories.select { |cat| cat['parent'].to_i.zero? }

      root_categories.each do |wp_cat|
        migrate_category(wp_cat, nil)
      end
    end

    def migrate_child_categories
      child_categories = wp_categories.reject { |cat| cat['parent'].to_i.zero? }

      child_categories.each do |wp_cat|
        parent_wp_id = wp_cat['parent']
        parent_category_id = mapping[parent_wp_id]

        if parent_category_id.nil?
          @errors << "Parent category not found for '#{wp_cat['name']}' (parent_id: #{parent_wp_id})"
          next
        end

        parent = Category.find_by(id: parent_category_id)
        unless parent&.is_root?
          @errors << "Parent '#{parent&.title}' is not a root category for '#{wp_cat['name']}'"
          next
        end

        migrate_category(wp_cat, parent)
      end
    end

    def migrate_category(wp_cat, parent = nil)
      wp_id = wp_cat['id']
      wp_slug = wp_cat['slug']
      wp_name = wp_cat['name']

      # Map category name
      mapped_name = map_category_name(wp_slug, wp_name)

      # Check if category already exists
      existing = if parent.nil?
                   Category.find_by(title: mapped_name, is_root: true)
      else
                   Category.find_by(title: mapped_name, parent_id: parent.id)
      end

      if existing
        @mapping[wp_id] = existing.id
        return existing
      end

      # Create new category
      slug = generate_unique_slug(mapped_name)
      category = Category.create!(
        title: mapped_name,
        slug: slug,
        description: wp_cat['description'],
        is_root: parent.nil?,
        parent: parent
      )

      @mapping[wp_id] = category.id
      category
    rescue StandardError => e
      @errors << "Failed to migrate category '#{wp_name}': #{e.message}"
      nil
    end

    def map_category_name(slug, name)
      # Try to find mapping by slug first
      mapped = CATEGORY_MAPPING[slug.downcase]
      return mapped if mapped

      # Check if any mapping value matches the name
      CATEGORY_MAPPING.each do |_key, value|
        return value if value.downcase == name.downcase
      end

      # Return original name if no mapping found
      name
    end

    def generate_unique_slug(title)
      base_slug = Slugify.convert(title)
      slug = base_slug
      counter = 1

      while Category.exists?(slug: slug)
        slug = "#{base_slug}-#{counter}"
        counter += 1
      end

      slug
    end
  end
end
