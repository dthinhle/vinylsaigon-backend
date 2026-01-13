# frozen_string_literal: true

module Admin::ProductListable
  extend ActiveSupport::Concern

  included do
    include SortableParams

    class_attribute :product_list_defaults
    self.product_list_defaults = { per_page: 25 }
  end

  def load_products_for(request, relation, filters: request.query_parameters.to_h)
    filters = parse_sort_by_params(filters.dup)

    products, active_filters, filter_errors, pagy = ProductFilterService.new(filters, relation, request:).apply_with_pagy(page: params[:page], per_page: product_list_defaults[:per_page])

    @products = products
    @products_pagy = pagy
    @product_active_filters = active_filters
    @product_filter_errors = filter_errors

    @pagy = pagy
    @active_filters = active_filters
    @filter_errors = filter_errors
  end

  class_methods do
    def set_product_list_defaults(opts = {})
      self.product_list_defaults = product_list_defaults.merge(opts)
    end
  end
end
