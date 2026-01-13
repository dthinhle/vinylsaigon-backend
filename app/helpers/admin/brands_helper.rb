module Admin::BrandsHelper
  # Mapping for sortable headers
  def brand_sortable_columns
    {
      'Name' => 'name',
      'Slug' => 'slug'
    }
  end

  # Table headers order
  def brand_table_headers
    [
      'Name', 'Slug', 'Created At', 'Actions',
    ]
  end

  # Renders headers with sorting links similar to products helper
  def render_brand_table_headers(params)
    current_sort, current_direction = params[:sort_by].present? ? params[:sort_by].rpartition('_').values_at(0, 2) : [nil, nil]
    current_direction ||= 'desc'

    headers = brand_table_headers
    sortable = brand_sortable_columns

    headers.map do |header|
      text_align = header == 'Actions' ? 'text-right' : 'text-left'
      if sortable[header]
        col = sortable[header]
        dir = (current_sort == col && current_direction == 'asc') ? 'desc' : 'asc'
        content_tag :th, class: "px-4 py-2 #{text_align} text-xs font-medium text-gray-500 uppercase" do
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
