# frozen_string_literal: true

require 'ostruct'

module Api
  module Seo
    class SitemapController < Api::BaseController
      CACHE_OPTIONS = { expires_in: 1.hour, public: true }.freeze

      def products
        expires_in CACHE_OPTIONS[:expires_in], public: CACHE_OPTIONS[:public]
        @products = Product.where(deleted_at: nil, status: statuses).select(:slug, :updated_at).order(updated_at: :desc)
      end

      def categories
        expires_in CACHE_OPTIONS[:expires_in], public: CACHE_OPTIONS[:public]
        @categories = Category.where(deleted_at: nil).select(:slug, :updated_at).order(updated_at: :desc)
      end

      def collections
        expires_in CACHE_OPTIONS[:expires_in], public: CACHE_OPTIONS[:public]
        @collections = ProductCollection.where(deleted_at: nil).select(:slug, :updated_at).order(updated_at: :desc)
      end

      def brands
        expires_in CACHE_OPTIONS[:expires_in], public: CACHE_OPTIONS[:public]
        @brands = Brand.where(deleted_at: nil).select(:slug, :updated_at).order(updated_at: :desc)
      end

      def blogs
        expires_in CACHE_OPTIONS[:expires_in], public: CACHE_OPTIONS[:public]
        @blogs = Blog.where(deleted_at: nil).where.not(published_at: nil).select(:slug, :updated_at).order(updated_at: :desc)
      end

      def menu_items
        expires_in CACHE_OPTIONS[:expires_in], public: CACHE_OPTIONS[:public]
        items = MenuBar::Item.select(:link, :updated_at).order(updated_at: :desc)

        # Sanitize and filter menu item links
        @menu_items = items.map do |i|
          sanitized_link = UrlSanitizer.process_path(i.link)
          sanitized_link ? OpenStruct.new(slug: sanitized_link, updated_at: i.updated_at) : nil
        end.compact
      end
    end
  end
end
