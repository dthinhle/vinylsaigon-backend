class ProductExportService
  DEFAULT_TIMEZONE = 'Hanoi'.freeze

  def self.call(product_ids:)
    new(product_ids: product_ids).call
  end

  def self.call_recent(hours:)
    new(hours: hours).call_recent
  end

  def initialize(product_ids: nil, hours: nil)
    @product_ids = product_ids
    @hours = hours
  end

  def call
    products_data = export_products
    json_data = products_data.to_json
    gzipped_data = gzip_data(json_data)

    timestamp = Time.current.in_time_zone(DEFAULT_TIMEZONE).strftime('%Y%m%d_%H%M%S')
    filename = "product_export_#{timestamp}.json.gz"

    { data: gzipped_data, filename: filename }
  end

  def call_recent
    products_data = export_recent_products
    json_data = products_data.to_json
    gzipped_data = gzip_data(json_data)

    timestamp = Time.current.in_time_zone(DEFAULT_TIMEZONE).strftime('%Y%m%d_%H%M%S')
    filename = "product_export_recent_#{@hours}h_#{timestamp}.json.gz"

    { data: gzipped_data, filename: filename }
  end

  private

  def export_recent_products
    cutoff_time = @hours.hours.ago

    product_ids = Set.new

    Product.where('updated_at >= ?', cutoff_time).pluck(:id).each { |id| product_ids.add(id) }

    ProductVariant.where('updated_at >= ?', cutoff_time).pluck(:product_id).each { |id| product_ids.add(id) }

    ProductImage.where("#{ProductImage.table_name}.updated_at >= ?", cutoff_time)
                .joins(:product_variant)
                .pluck('product_variants.product_id')
                .each { |id| product_ids.add(id) }

    products = Product.where(id: product_ids.to_a)
                     .includes(
                       :category,
                       :brands,
                       :product_collections,
                       product_variants: { product_images: { image_attachment: :blob } }
                     )

    products.map do |product|
      export_product(product)
    end
  end

  def export_products
    products = Product.where(id: @product_ids)
                     .includes(
                       :category,
                       :brands,
                       :product_collections,
                       product_variants: { product_images: { image_attachment: :blob } }
                     )

    products.map do |product|
      export_product(product)
    end
  end

  def export_product(product)
    {
      product: product_attributes(product),
      category: product.category ? category_attributes(product.category) : nil,
      brands: product.brands.map { |brand| brand_attributes(brand) },
      collections: product.product_collections.map { |collection| collection_attributes(collection) },
      variants: product.product_variants.map { |variant| export_variant(variant) }
    }
  end

  def product_attributes(product)
    attrs = product.attributes.except('id', 'created_at', 'updated_at', 'category_id').merge(
      category_slug: product.category&.slug,
    )

    Product::LEXICAL_COLUMNS.each do |column|
      if attrs[column].present?
        attrs[column] = LexicalContentProcessorService.process_for_export(attrs[column])
      end
    end

    attrs
  end

  def category_attributes(category)
    {
      title: category.title,
      slug: category.slug,
      description: category.description,
      is_root: category.is_root,
      parent_slug: category.parent&.slug
    }
  end

  def brand_attributes(brand)
    {
      name: brand.name,
      slug: brand.slug
    }
  end

  def collection_attributes(collection)
    {
      name: collection.name,
      slug: collection.slug,
      description: collection.description
    }
  end

  def export_variant(variant)
    {
      attributes: variant.attributes.except('id', 'product_id', 'created_at', 'updated_at'),
      images: variant.product_images.order(position: :asc).map { |pi| export_product_image(pi) }
    }
  end

  def export_product_image(product_image)
    return nil unless product_image.image.attached?

    blob = product_image.image.blob
    {
      filename: product_image.filename,
      position: product_image.position,
      url: PublicImagePathService.handle(blob),
      content_type: blob.content_type,
      byte_size: blob.byte_size,
      checksum: blob.checksum
    }
  end

  def gzip_data(data)
    compressed_string = StringIO.new
    gz = Zlib::GzipWriter.new(compressed_string)
    gz.write(data)
    gz.close
    compressed_string.string
  end
end
