require 'zlib'
require 'open-uri'

class ProductImportService
  REDIS_KEY = 'product_import_progress'.freeze

  def self.call(file_path:, import_id:, import_options:)
    new(file_path: file_path, import_id: import_id, import_options: import_options).call
  end

  def initialize(file_path:, import_id:, import_options:)
    @file_path = file_path
    @import_id = import_id
    @import_options = import_options
    @mode = import_options[:mode] || 'upsert'
    @auto_create_categories = import_options[:auto_create_categories] || false
    @auto_create_brands = import_options[:auto_create_brands] || false
    @errors = []
    @imported_count = 0
    @updated_count = 0
    @skipped_count = 0
  end

  def call
    products_data = parse_gzipped_json
    total = products_data.size

    update_progress(0, total, 'processing')

    products_data.each_with_index do |product_data, index|
      begin
        import_product(product_data)
        @imported_count += 1
      rescue StandardError => e
        @errors << "Product SKU #{product_data.dig('product', 'sku')}: #{e.message}"
        @skipped_count += 1
        Rails.logger.error "Import error for product: #{e.message}\n#{e.backtrace.join("\n")}"
      end

      update_progress(index + 1, total, 'processing')
    end

    finalize_import(total)
  rescue StandardError => e
    Rails.logger.error "Import service error: #{e.message}\n#{e.backtrace.join("\n")}"
    update_progress(0, 0, 'error', "Import failed: #{e.message}")
  end

  private

  def parse_gzipped_json
    File.open(@file_path, 'rb') do |file|
      gz = Zlib::GzipReader.new(file)
      json_data = gz.read
      gz.close
      JSON.parse(json_data)
    end
  end

  def import_product(product_data)
    product_attrs = product_data['product']
    category_data = product_data['category']
    brands_data = product_data['brands'] || []
    collections_data = product_data['collections'] || []
    variants_data = product_data['variants'] || []

    sku = product_attrs['sku']
    existing_product = Product.find_by(sku: sku)

    return if @mode == 'create' && existing_product.present?
    return if @mode == 'update' && existing_product.nil?

    category = find_or_create_category(category_data) if category_data
    brands = brands_data.map { |brand_data| find_or_create_brand(brand_data) }.compact
    collections = collections_data.map { |col_data| find_or_create_collection(col_data) }.compact

    ActiveRecord::Base.transaction do
      product = upsert_product(product_attrs, category)
      product.brands = brands if brands.any?
      product.product_collections = collections if collections.any?

      if variants_data.any?
        expected_variant_skus = variants_data.map { |vd| vd['attributes']['sku'] }.compact

        variants_data.each do |variant_data|
          upsert_variant(product, variant_data)
        end

        product.product_variants.where.not(sku: expected_variant_skus).destroy_all
      end

      @updated_count += 1 if existing_product.present?
    end
  end

  def find_or_create_category(category_data)
    slug = category_data['slug']
    category = Category.find_by(slug: slug)

    return category if category.present?
    return nil unless @auto_create_categories

    parent = nil
    if category_data['parent_slug'].present?
      parent = Category.find_by(slug: category_data['parent_slug'])
      parent ||= Category.create!(
        title: category_data['parent_slug'].titleize,
        slug: category_data['parent_slug'],
        is_root: true
      ) if @auto_create_categories
    end

    Category.create!(
      title: category_data['title'],
      slug: slug,
      description: category_data['description'],
      is_root: category_data['is_root'] || false,
      parent: parent
    )
  end

  def find_or_create_brand(brand_data)
    slug = brand_data['slug']
    brand = Brand.find_by(slug: slug)

    return brand if brand.present?
    return nil unless @auto_create_brands

    Brand.create!(
      name: brand_data['name'],
      slug: slug
    )
  end

  def find_or_create_collection(collection_data)
    slug = collection_data['slug']
    ProductCollection.find_by(slug: slug)
  end

  def upsert_product(product_attrs, category)
    sku = product_attrs['sku']
    product = Product.find_or_initialize_by(sku: sku)

    content_keys = product_attrs.delete('content_keys')
    processed_attrs = product_attrs.except('sku', 'category_slug').merge(category: category)

    Product::LEXICAL_COLUMNS.each do |column|
      if processed_attrs[column].present?
        processed_attrs[column] = LexicalContentProcessorService.process_for_import(
          processed_attrs[column],
          product
        )
      end
    end

    product.assign_attributes(processed_attrs)
    product.save!

    cleanup_orphaned_content_attachments(product, content_keys) if content_keys.present?

    product
  end

  def cleanup_orphaned_content_attachments(product, content_keys)
    return unless product.persisted?

    expected_image_checksums = (content_keys['content_images'] || []).to_set
    expected_video_checksums = (content_keys['content_videos'] || []).to_set

    if product.content_images.attached?
      product.content_images.each do |attachment|
        attachment.purge if attachment.blob.present? && !expected_image_checksums.include?(attachment.blob.checksum)
      end
    end

    if product.content_videos.attached?
      product.content_videos.each do |attachment|
        attachment.purge if attachment.blob.present? && !expected_video_checksums.include?(attachment.blob.checksum)
      end
    end
  end

  def upsert_variant(product, variant_data)
    variant_attrs = variant_data['attributes']
    images_data = variant_data['images'] || []

    variant_sku = variant_attrs['sku']
    variant = product.product_variants.find_or_initialize_by(sku: variant_sku)

    variant.assign_attributes(variant_attrs.except('sku'))
    variant.save!

    if images_data.any?
      import_variant_images(variant, images_data)
    end

    variant
  end

  def import_variant_images(variant, images_data)
    expected_checksums = images_data.map { |img| img['checksum'] }.compact.to_set

    variant.product_images.each do |product_image|
      should_delete = if product_image.image.attached?
                        !expected_checksums.include?(product_image.image.blob.checksum)
      else
                        true
      end
      product_image.destroy if should_delete
    end

    images_data.each do |image_data|
      begin
        existing_image = variant.product_images.find_by(filename: image_data['filename'])

        if existing_image
          existing_image.update!(position: image_data['position'])
        else
          product_image = variant.product_images.build(
            filename: image_data['filename'],
            position: image_data['position']
          )

          existing_blob = ActiveStorage::Blob.find_by(checksum: image_data['checksum'])

          if existing_blob
            product_image.image.attach(existing_blob)
          else
            downloaded_file = download_image(image_data['url'])
            next unless downloaded_file

            product_image.image.attach(
              io: downloaded_file,
              filename: image_data['filename'],
              content_type: image_data['content_type']
            )
          end

          product_image.save!
        end
      rescue StandardError => e
        Rails.logger.error "Failed to import image #{image_data['url']}: #{e.message}"
      end
    end
  end

  def download_image(url)
    URI.open(url, 'rb')
  rescue StandardError => e
    Rails.logger.error "Failed to download image from #{url}: #{e.message}"
    nil
  end

  def update_progress(current, total, status, message = nil)
    progress_data = {
      status: status,
      progress: current,
      total: total,
      imported_count: @imported_count,
      updated_count: @updated_count,
      skipped_count: @skipped_count,
      errors: @errors
    }
    progress_data[:message] = message if message

    progress_data[:import_id] = @import_id
    Rails.cache.write(REDIS_KEY, progress_data, expires_in: 1.hour)
  end

  def finalize_import(total)
    final_message = "Import completed: #{@imported_count} imported, #{@updated_count} updated, #{@skipped_count} skipped"
    update_progress(total, total, 'completed', final_message)
  end
end
