# frozen_string_literal: true

module Api
  class StaticController < Api::BaseController
    def menu_bar
      @sections = MenuBar::Section.includes(items: :sub_items).all
      @featured_product = Product
        .includes(:product_variants)
        .active
        .order(price_updated_at: :desc).limit(20).sample
    end

    def landing_page
      @categories = Category.root_categories
      @banners = HeroBanner.order(created_at: :desc)
    end

    def global
      @store = Store.last
      @addresses = @store.addresses
    end

    def search_items
      result = SearchSuggestionService.call
      @popular_searches = result[:popular_searches]
      @for_you_content = result[:for_you_content]
    end
  end
end
