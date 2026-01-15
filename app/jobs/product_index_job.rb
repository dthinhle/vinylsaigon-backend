class ProductIndexJob < ApplicationJob
  include Rails.application.routes.url_helpers
  queue_as :default

  attr_reader :product

  def perform(product_id)
    fetch_product(product_id)
    return if product.nil?

    product_index_object = build_product_index_object
    simple_index_object = product_index_object.slice(
      :id, :name,
      :meta_title, :meta_description,
      :slug, :variants
    )

    products_index.add_documents(product_index_object.deep_transform_keys { |k| k.to_s.camelize(:lower) })
    products_search_index.add_documents(simple_index_object.deep_transform_keys { |k| k.to_s.camelize(:lower) })
  end

  private

  def products_index
    MEILISEARCH_CLIENT.index('products')
  end

  def products_search_index
    MEILISEARCH_CLIENT.index('products_search')
  end

  def fetch_product(product_id)
    @product = Product.find_by(id: product_id)
    if !product || product.inactive?
      Rails.logger.info("Product ID #{product_id} is inactive or removed. Removing from index if exists.")

      products_index.delete_document(product_id)
      products_search_index.delete_document(product_id)
      @product = nil
    end
  end

  def build_product_index_object
    product_hash = {
      **product.attributes.symbolize_keys.slice(:id, :name, :status, :slug, :created_at),
      updated_at: product.price_updated_at || product.updated_at,
      description: LexicalConverterService.call(product.description, format: :plain_text),
      short_description: LexicalConverterService.call(product.short_description, format: :plain_text),
      current_price: product.current_price || product.original_price,
      flags: product.formatted_flags,
      seo: {
        title: product.meta_title,
        description: product.meta_description
      },
      brands: product.brands.pluck(:name),
      categories: build_category_hierarchy,
      collections: product.product_collections.pluck(:name),
      tags: product.product_tags,
      product_attributes: normalize_attributes_for_indexing(product.product_attributes),
      variants: product.product_variants.map do |variant|
        {
          **variant.attributes.symbolize_keys.slice(:name, :slug, :short_description, :status, :original_price),
          variant_attributes: normalize_attributes_for_indexing(variant.variant_attributes),
          current_price: variant.current_price || variant.original_price,
          images: variant.images.map { |img| ImagePathService.new(img).thumbnail_path }
        }
      end
    }

    transform_decimals(product_hash)
  end

  private

  def normalize_attributes_for_indexing(attrs)
    return {} if attrs.blank?

    # Check if new format (has 'attributes' key with array value)
    if attrs.is_a?(Hash) && attrs.key?('attributes') && attrs['attributes'].is_a?(Array)
      # Return the array directly for indexing
      attrs['attributes']
    elsif attrs.is_a?(Hash)
      # Old format: convert hash to array
      attrs.map { |k, v| { 'name' => k, 'value' => v } }
    else
      {}
    end
  end

  def transform_decimals(obj)
    case obj
    when BigDecimal
      obj.to_f
    when Hash
      obj.transform_values { |value| transform_decimals(value) }
    when Array
      obj.map { |item| transform_decimals(item) }
    else
      obj
    end
  end

  def build_category_hierarchy
    return {} unless product.category

    hierarchy = {}
    current = product.category
    paths = []

    while current
      paths.unshift(current.title)
      current = current.parent
    end

    paths.each_with_index do |path, index|
      hierarchy["lv#{index}"] = paths[0..index].join(' > ')
    end

    hierarchy
  end
end
