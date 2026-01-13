class SearchSuggestionService
  SAMPLE_SIZE = 5
  ADDITIONAL_COLLECTIONS_SIZE = 3

  def self.call
    new.call
  end

  def call
    {
      popular_searches: fetch_popular_searches,
      for_you_content: fetch_for_you_content
    }
  end

  private

  def fetch_popular_searches
    featured_products = Product
      .active
      .order(price_updated_at: :desc)
      .limit(SAMPLE_SIZE * 3)

    categories = Category
      .root_categories
      .limit(SAMPLE_SIZE * 2)

    combined = []
    featured_products.each { |p| combined << { type: 'product', item: p } }
    categories.each { |c| combined << { type: 'category', item: c } }

    combined.sample(SAMPLE_SIZE)
  end

  def fetch_for_you_content
    items = []

    new_arrivals = ProductCollection.find_by(name: I18n.t('collections.new_arrivals.name', locale: :vi))
    on_sale = ProductCollection.find_by(name: I18n.t('collections.on_sale.name', locale: :vi))

    items << { type: 'collection', item: new_arrivals } if new_arrivals
    items << { type: 'collection', item: on_sale } if on_sale

    additional_collections = ProductCollection
      .where.not(id: [new_arrivals&.id, on_sale&.id].compact)
      .limit(ADDITIONAL_COLLECTIONS_SIZE * 2)

    additional_categories = Category
      .root_categories
      .limit(ADDITIONAL_COLLECTIONS_SIZE * 2)

    combined = []
    additional_collections.each { |c| combined << { type: 'collection', item: c } }
    additional_categories.each { |c| combined << { type: 'category', item: c } }

    items.concat(combined.sample(ADDITIONAL_COLLECTIONS_SIZE))
  end
end
