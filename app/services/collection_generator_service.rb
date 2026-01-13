class CollectionGeneratorService
  NEW_ARRIVALS_LIMIT = 40

  def self.call
    new.call
  end

  def call
    generate_new_arrivals_collection
    generate_on_sale_collection
  end

  private

  def generate_new_arrivals_collection
    collection = find_or_create_collection(
      I18n.t('collections.new_arrivals.name', locale: :vi),
      I18n.t('collections.new_arrivals.description', locale: :vi)
    )

    current_product_ids = collection.products.pluck(:id)

    latest_products = Product.active
                             .order(created_at: :desc)
                             .limit(NEW_ARRIVALS_LIMIT)

    collection.products = latest_products

    new_product_ids = latest_products.pluck(:id)
    changed_ids = [*current_product_ids, *new_product_ids] - (current_product_ids & new_product_ids)
    changed_ids.uniq.each do |product_id|
      ProductIndexJob.perform_later(product_id)
    end

    Rails.logger.info "CollectionGeneratorService: Updated New Arrivals collection with #{latest_products.count} products"
  end

  def generate_on_sale_collection
    collection = find_or_create_collection(
      I18n.t('collections.on_sale.name', locale: :vi),
      I18n.t('collections.on_sale.description', locale: :vi)
    )

    current_product_ids = collection.products.pluck(:id)

    on_sale_products = Product.active
                              .on_sale
                              .order(:sort_order, :name)

    collection.products = on_sale_products

    new_product_ids = on_sale_products.pluck(:id)

    changed_ids = [*current_product_ids, *new_product_ids] - (current_product_ids & new_product_ids)
    changed_ids.uniq.each do |product_id|
      ProductIndexJob.perform_later(product_id)
    end

    Rails.logger.info "CollectionGeneratorService: Updated On Sale collection with #{on_sale_products.count} products"
  end

  def find_or_create_collection(name, description)
    ProductCollection.find_or_create_by(name: name) do |collection|
      collection.description = description
    end
  end
end
