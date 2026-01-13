# frozen_string_literal: true

module Api
  module Seo
    class PaginatedProductsController < Api::BaseController
      # Provides a paginated JSON endpoint that includes SEO metadata (rel prev/next links)
      # Frontend will call this to reliably build rel="prev" / rel="next" tags for crawlers.
      def index
        filters = request.query_parameters.to_h

        filter_service = ProductFilterService.new(
          filters,
          Product.where(deleted_at: nil),
          request: request
        )

        products, active_filters, filter_errors, pagy = filter_service.apply_with_pagy(
          page: params[:page]&.to_i || 1,
          per_page: params[:per_page]&.to_i || 24
        )

        # Pagy::Offset has a slightly different API (no `items` / `prev`/`next`/`pages` helpers),
        # so compute values defensively to support both Pagy::Elastic/Classic and Pagy::Offset.
        per_page = pagy.respond_to?(:items) ? pagy.items : (pagy.respond_to?(:limit) ? pagy.limit : params[:per_page]&.to_i || 24)
        total_count = pagy.respond_to?(:count) ? pagy.count : 0
        total_pages = if pagy.respond_to?(:pages) && pagy.pages.present?
                        pagy.pages
        else
                        per_page.positive? ? (total_count.to_f / per_page).ceil : 1
        end
        current_page = pagy.respond_to?(:page) ? pagy.page : (params[:page]&.to_i || 1)
        previous_page = current_page > 1 ? current_page - 1 : nil
        next_page = current_page < total_pages ? current_page + 1 : nil

        pagination_metadata = {
          current_page: current_page,
          total_pages: total_pages,
          total_count: total_count,
          per_page: per_page,
          has_previous: previous_page.present?,
          has_next: next_page.present?,
          first_page_url: api_seo_paginated_products_url(page: 1, **request.query_parameters.except(:page)),
          last_page_url: api_seo_paginated_products_url(page: total_pages, **request.query_parameters.except(:page)),
          previous_page_url: previous_page.present? ? api_seo_paginated_products_url(page: previous_page, **request.query_parameters.except(:page)) : nil,
          next_page_url: next_page.present? ? api_seo_paginated_products_url(page: next_page, **request.query_parameters.except(:page)) : nil
        }

        render json: {
          products: products.map { |p| product_summary(p) },
          pagination: pagination_metadata,
          seo_metadata: generate_seo_metadata(pagy, request),
          filters: active_filters
        }
      end

      private

      def product_summary(product)
        summary = {
          id: product.id,
          name: product.name,
          slug: product.slug,
          updated_at: product.updated_at
        }
        summary[:price] = product.current_price if product.respond_to?(:current_price)
        summary.compact
      end

      def generate_seo_metadata(pagy, request)
        # Compute prev/next pages in a way that works across Pagy adapters
        per_page = pagy.respond_to?(:items) ? pagy.items : (pagy.respond_to?(:limit) ? pagy.limit : nil)
        total_count = pagy.respond_to?(:count) ? pagy.count : nil
        total_pages = if pagy.respond_to?(:pages) && pagy.pages.present?
                        pagy.pages
        elsif per_page && total_count
                        per_page.positive? ? (total_count.to_f / per_page).ceil : 1
        end
        current_page = pagy.respond_to?(:page) ? pagy.page : nil

        prev_page = if pagy.respond_to?(:prev)
                      pagy.prev
        elsif current_page && current_page > 1
                      current_page - 1
        end

        next_page = if pagy.respond_to?(:next)
                      pagy.next
        elsif current_page && total_pages && current_page < total_pages
                      current_page + 1
        end

        seo_links = []
        seo_links << { rel: 'prev', url: api_seo_paginated_products_url(page: prev_page, **request.query_parameters.except(:page)) } if prev_page.present?
        seo_links << { rel: 'next', url: api_seo_paginated_products_url(page: next_page, **request.query_parameters.except(:page)) } if next_page.present?

        { links: seo_links }
      end
    end
  end
end
