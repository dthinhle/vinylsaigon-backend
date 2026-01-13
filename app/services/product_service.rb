# frozen_string_literal: true

class ProductService
  extend ImageAttachable

  class PartialUpdateResult
    attr_accessor :product, :success, :warnings, :errors

    def initialize(product)
      @product = product
      @success = true
      @warnings = []
      @errors = []
    end

    def add_warning(message)
      @warnings << message
    end

    def add_error(message)
      @errors << message
      @success = false
    end

    def partial_success?
      @success && @warnings.any?
    end
  end

  def self.create_product(product_params, variant_params = nil, single_images = nil)
    %i[short_description description].each do |attr|
      product_params[attr] = parse_json_content(product_params[attr]) if product_params[attr].present?
    end
    product = Product.new(product_params.except(:original_price, :current_price, :related_product_ids))
    product.skip_auto_flags = product_params[:skip_auto_flags] || false

    ActiveRecord::Base.transaction do
      product.save!

      if product.persisted? && product_params[:related_product_ids].is_a?(Array)
        product.update(related_product_ids: product_params[:related_product_ids].reject(&:blank?))
      end

      sanitized, delete_ids = sanitize_variant_params(product, variant_params)

      if delete_ids.any?
        product.product_variants.where(id: delete_ids).destroy_all
      end

      if sanitized.size == 1
        handle_single_variant(product, product_params, single_images, nil)
      else
        sync_variants(product, sanitized)
        handle_multiple_variants(product, variant_params)
      end

      product
    end
  end

  def self.update_product(product, product_params, variant_params = nil, image_params = {})
    result = PartialUpdateResult.new(product)
    begin
      ActiveRecord::Base.transaction do
        %i[short_description description].each do |attr|
          product_params[attr] = parse_json_content(product_params[attr]) if product_params[attr].present?
        end
        product.skip_auto_flags = product_params[:skip_auto_flags] || false
        sanitize_attributes_field(product, product_params, field: :product_attributes)
        product.update!(product_params.except(:original_price, :current_price, :skip_auto_flags))

        sanitized, delete_ids = sanitize_variant_params(product, variant_params)

        if delete_ids.any?
          product.product_variants.where(id: delete_ids).destroy_all
        end

        default_variant_changed = false

        if sanitized.any?
          first_variant = sanitized.shift
          default_variant = product.product_variants.find_by(sku: first_variant[:sku])
          default_variant ||= product.product_variants.first
          permitted_variant_attrs = permit_variant_attributes(first_variant)
          sanitize_attributes_field(default_variant, permitted_variant_attrs, field: :variant_attributes)
          default_variant.assign_attributes(permitted_variant_attrs)
          default_variant.save!

          default_variant_changed = update_product_images(
            default_variant,
            first_variant[:product_images_attributes],
            image_params[:single_images],
            first_variant.fetch(:product_images_positions, [])
          )

          if sanitized.any?
            sync_variants(product, [first_variant, *sanitized])
          else
            submitted_skus = [default_variant.sku]
            product.product_variants.where.not(sku: submitted_skus).delete_all
            product.product_variants.reset
          end
        elsif product.product_variants.empty?
          create_default_variant(product)
        end

        product.reload
        if product.product_variants.count == 1
          new_images = default_variant_changed ? [] : image_params[:single_images]
          handle_single_variant(product, product_params, new_images, image_params[:single_remove_ids])
        elsif variant_params.present?
          handle_multiple_variants(product, variant_params, image_params[:single_remove_ids])
        end
      end
    rescue StandardError => e
      Rails.logger.error("Transaction failed during product update: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      result.add_error(e.message)
      Rails.logger.error("Product update failed: #{e.message}")
    end

    result
  end

  def self.sanitize_variant_params(product, variant_params)
    return [[], []] unless variant_params.present?

    sanitized = []
    delete_ids = []
    skus_seen = Set.new

    variant_params.each do |_index, attrs|
      if (attrs[:_destroy].to_s == '1' || attrs[:_destroy].to_s == 'true') && attrs[:id].present?
        delete_ids << attrs[:id]
        next
      end

      sku = attrs[:sku]&.strip
      sku = "#{Slugify.convert(attrs[:name] || 'default', true) || 'variant'}".upcase if sku.blank?

      raise StandardError, "Duplicate SKU '#{sku}' in submitted variants" if skus_seen.include?(sku)

      skus_seen << sku
      sanitized << attrs.merge(sku: sku)
    end

    [sanitized, delete_ids]
  end

  def self.sync_variants(product, sanitized_params)
    return if sanitized_params.empty?

    sanitized_params.each_with_index do |attrs, index|
      variant = if index.zero? && product.product_variants.size == 1
        product.product_variants.first
      else
        product.product_variants.where(id: attrs[:id]).first
      end
      variant ||= product.product_variants.find_or_initialize_by(sku: attrs[:sku])
      permitted_variant_attrs = permit_variant_attributes(attrs)
      sanitize_attributes_field(variant, permitted_variant_attrs, field: :variant_attributes)
      variant.assign_attributes(permitted_variant_attrs)
      variant.save!
    end
  end

  def self.sanitize_attributes_field(record, attributes, field:)
    return unless attributes.respond_to?(:key?) && attributes.key?(field) && attributes[field].is_a?(String)

    begin
      parsed = JSON.parse(attributes[field])

      # Convert old format to new format if needed
      if parsed.is_a?(Hash) && !parsed.key?('attributes')
        Rails.logger.info("Converting #{field} from old format to new format for #{record.class.name}")
        attributes[field] = { 'attributes' => parsed.map { |k, v| { 'name' => k, 'value' => v } } }
      else
        attributes[field] = parsed
      end
    rescue JSON::ParserError => e
      Rails.logger.warn("Invalid JSON: #{attributes[field]}")
      Rails.logger.warn("Failed to parse JSON for #{record.class.name} field #{field}: #{e.message}")
    end
  end

  def self.handle_single_variant(product, product_params, new_images, remove_image_ids)
    variant = product.product_variants.first

    variant.update!(
      name: 'Default',
      sku: product.sku,
      slug: product.slug || Slugify.convert(product.name, true),
      original_price: product_params[:original_price] || variant.original_price,
      current_price: product_params[:current_price] || variant.current_price,
      status: 'active'
    )

    if new_images.present? || remove_image_ids.present?
      # For single product mode, still use direct attachments for backward compatibility
      # Or switch to ProductImage if needed:
      update_images_advanced(variant, remove_image_ids, new_images)
    end
  end

  def self.handle_multiple_variants(product, variant_params, remove_image_ids = [])
    variant_params.each do |_index, attrs|
      if attrs[:_destroy].to_s == '1' || attrs[:_destroy].to_s == 'true'
        variant = product.product_variants.find_by(id: attrs[:id])
        variant.destroy if variant
        next
      end

      variant = product.product_variants.find_by(id: attrs[:id])
      variant ||= product.product_variants.find_by(sku: attrs[:sku])
      next unless variant

      # Handle ProductImage with positions
      if attrs[:product_images_attributes].present? || attrs[:product_images].compact.present?
        update_product_images(
          variant,
          attrs[:product_images_attributes],
          attrs[:product_images],
          attrs[:product_images_positions]
        )
      end
    end
  end

  def self.create_default_variant(product)
    return if product.product_variants.exists?

    product.product_variants.build(
      name: 'Default',
      sku: product.sku,
      slug: product.slug || Slugify.convert(product.name, true),
      original_price: nil,
      status: 'active'
    )
  end

  def self.destroy_selected_products(product_ids)
    ids = Array(product_ids).map(&:to_i)
    return { success: false, message: 'No products selected for deletion.' } if ids.empty?

    products = Product.where(id: ids)
    found_ids = products.pluck(:id)
    not_found_ids = ids - found_ids

    destroyed = Product.destroy(found_ids)
    destroyed_ids = Array(destroyed).select(&:destroyed?).map(&:id)
    failed = found_ids - destroyed_ids

    messages = []
    messages << "Products not found: #{not_found_ids.join(', ')}." if not_found_ids.any?
    messages << "Failed to delete products: #{failed.join(', ')}." if failed.any?

    success = not_found_ids.empty? && failed.empty?

    {
      success: success,
      message: success ? 'Selected products deleted successfully.' : messages.join(' '),
      not_found: not_found_ids,
      failed: failed
    }
  end

  def self.related_products(products, limit: 8)
    categories = products.flat_map(&:category).uniq.compact
    return [] if categories.empty?

    all_product_ids = products.map(&:id)
    related_products = []
    used_product_ids = all_product_ids.dup

    linked_products = products.flat_map(&:related_products)
      .reject { |p| used_product_ids.include?(p.id) }
      .uniq
    linked_product_ids = linked_products.map(&:id)

    # Tier 0: Related products from product groups (weighted limit: 2.5x, max: 20)
    fetch_tier0_products(linked_products, limit, used_product_ids, related_products)

    # Tier 1: Related products from child categories (weighted)
    fetch_tier1_products(categories, limit, used_product_ids, related_products) if related_products.size < limit

    # Tier 2: Related products from parent categories (if not at limit)
    fetch_tier2_products(categories, limit, used_product_ids, related_products) if related_products.size < limit

    # Tier 3: Random recent products (if still not at limit)
    fetch_tier3_products(limit, used_product_ids, related_products) if related_products.size < limit

    related_products.sort_by { |p| [linked_product_ids.include?(p.id) ? 0 : 1, -p.created_at.to_i] }.first(limit)
  end

  def self.other_products(product, limit: 8)
    fetched_products =
      Product.includes(
        :brands,
        :product_collections,
        :product_variants
      ).joins(:product_variants)
      .select(:id, 'products.*')
      .distinct
      .active
      .where(category: product.category)
      .where("\"#{ProductVariant.table_name}\".\"original_price\" IS NOT NULL")
      .order(price_updated_at: :desc)
      .limit(limit * 5)
      .sample(limit + 1) # Fetch extra to account for filtering, `NOT IN` clause doesn't use index efficiently

    fetched_products.reject { |p| p.id == product.id }.first(limit)
  end

  private

  def self.fetch_tier0_products(linked_products, limit, used_product_ids, related_products)
    return unless linked_products.any?
    weighted_limit = [limit * 2.5, 20].min.to_i

    products_with_includes = Product.includes(
      :category,
      :brands,
      :product_variants
    ).where(id: linked_products.map(&:id), status: 'active').to_a

    tier0_products = products_with_includes.sample([weighted_limit, products_with_includes.size].min)

    related_products.concat(tier0_products)
    used_product_ids.concat(tier0_products.map(&:id))
  end

  def self.fetch_tier1_products(categories, limit, used_product_ids, related_products)
    return if related_products.size >= limit

    related_categories = categories.flat_map { |cat| cat.random_related_categories }.uniq.compact
    return unless related_categories.any?

    remaining_limit = limit - related_products.size
    tier1_products = fetch_products_by_categories(related_categories, remaining_limit, used_product_ids)

    related_products.concat(tier1_products)
    used_product_ids.concat(tier1_products.map(&:id))
  end

  def self.fetch_tier2_products(categories, limit, used_product_ids, related_products)
    return if related_products.size >= limit

    parent_categories = categories.map(&:parent).compact.uniq
    return unless parent_categories.any?

    remaining_limit = limit - related_products.size
    tier2_products = fetch_products_by_categories(parent_categories, remaining_limit, used_product_ids)

    related_products.concat(tier2_products)
    used_product_ids.concat(tier2_products.map(&:id))
  end

  def self.fetch_tier3_products(limit, used_product_ids, related_products)
    return if related_products.size >= limit

    remaining_limit = limit - related_products.size

    tier3_products = Product.includes(
      :category,
      :brands,
      :product_collections,
      :product_variants
    ).where(price_updated_at: 12.months.ago.., status: 'active')
     .sample(remaining_limit + used_product_ids.size) # Fetch extra to account for filtering, `NOT IN` clause doesn't use index efficiently

    tier3_products.reject! { |p| used_product_ids.include?(p.id) }
    related_products.concat(tier3_products.first(remaining_limit))
  end

  def self.parse_json_content(json_string)
    JSON.parse(json_string)
  rescue JSON::ParserError => e
    Rails.logger.warn("Failed to parse JSON content: #{e.message}")

    WordpressMigration::DataCleaner.clean_html(<<~HTML)
      <p>#{json_string}</p>
    HTML
  end

  def self.fetch_products_by_categories(categories, limit, used_product_ids)
    products_array = Product.includes(
      :category,
      :brands,
      :product_collections,
      :product_variants
    ).joins(:category)
     .active
     .where(category: categories, price_updated_at: 6.months.ago..)
     .where("\"#{ProductVariant.table_name}\".\"original_price\" IS NOT NULL")
     .limit(limit * 2 + used_product_ids.size) # Fetch extra to account for filtering, `NOT IN` clause doesn't use index efficiently

    products_array = products_array.reject { |p| used_product_ids.include?(p.id) }
    return products_array.sample(limit) if products_array.size > limit

    products_array
  end

  def self.permit_variant_attributes(variant_attrs)
    params = variant_attrs.is_a?(ActionController::Parameters) ? variant_attrs : ActionController::Parameters.new(variant_attrs)

    params.permit(
      :id,
      :name,
      :sku,
      :slug,
      :original_price,
      :current_price,
      :status,
      :sort_order,
      :variant_attributes
    )
  end
end
