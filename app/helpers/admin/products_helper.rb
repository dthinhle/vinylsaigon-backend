module Admin::ProductsHelper
  # Returns the mapping of sortable headers to column names
  def product_sortable_columns
    {
      'Name' => 'name',
      'SKU' => 'sku',
      'Slug' => 'slug',
      'Base Price' => 'original_price',
      'Current Price' => 'current_price',
      'Status' => 'status',
      'Stock Status' => 'stock_status',
      'Stock Quantity' => 'stock_quantity',
      'Featured' => 'featured',
      'Created At' => 'created_at',
      'Updated At' => 'updated_at',
      'Sort Order' => 'sort_order'
    }
  end

  # Returns the ordered list of all headers for the products table
  def product_table_headers
    [
      'Name', 'SKU', 'Categories', 'Brand', 'Flags', 'Base Price',
      'Current Price', 'Status', 'Updated At', 'Created At', 'Actions',
    ]
  end

  # Renders the table headers with sorting links where applicable.
  # Supports variants: :default, :brand, :category and accepts an explicit headers: array.
  def render_product_table_headers(params, variant: :default, headers: nil)
    current_sort, current_direction = params[:sort_by].present? ? params[:sort_by].rpartition('_').values_at(0, 2) : [nil, nil]
    current_direction ||= 'desc'

    # Preset header lists and sortable mappings for variants
    brand_headers = [
      'ID', 'Name', 'SKU', 'Price', 'Status', 'Created At', 'Actions',
    ]
    brand_sortable = {
      'ID' => 'id',
      'Name' => 'name',
      'SKU' => 'sku',
      'Price' => 'original_price',
      'Status' => 'status',
      'Stock Quantity' => 'stock_quantity',
      'Created At' => 'created_at'
    }

    # Fallback to products default
    headers = variant == :brand ? brand_headers : product_table_headers
    sortable = variant == :brand ? brand_sortable : product_sortable_columns

    headers.map do |header|
      text_align = header == 'Actions' ? 'text-right sticky bg-gray-50 right-0 z-10' : 'text-left'
      if sortable[header]
        col = sortable[header]
        dir = (current_sort == col && current_direction == 'asc') ? 'desc' : 'asc'
        content_tag :th, class: "p-2 #{text_align} text-xs font-medium text-gray-500 uppercase" do
          link_to(
            "#{header}#{current_sort == col ? (current_direction == 'asc' ? ' ▲' : ' ▼') : ''}".html_safe,
            url_for(request.query_parameters.merge(sort_by: [col, dir].join('_'), page: nil)),
            class: "hover:underline #{current_sort == col ? 'text-gray-950' : ''}"
          )
        end
      else
        content_tag :th, header, class: "px-4 py-2 #{text_align} text-xs font-medium text-gray-500 uppercase"
      end
    end.join.html_safe
  end
end
