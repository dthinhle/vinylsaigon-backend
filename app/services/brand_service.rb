# frozen_string_literal: true

class BrandService
  # Filters, searches, sorts, and paginates brands
  # Returns: [brands, active_filters, filter_errors, pagy]
  def self.filter_brands(params, request: nil)
    raise ArgumentError, 'Request object is required' if request.nil?

    filter = BrandFilterService.new(params)
    filtered_brands, active_filters, filter_errors = filter.apply
    pagy = Pagy::Offset.new(count: filtered_brands.count, page: params[:page], request: Pagy::Request.new(request:))
    paginated_brands = filtered_brands.offset(pagy.offset).limit(pagy.limit)
    [paginated_brands, active_filters, filter_errors, pagy]
  end
end
