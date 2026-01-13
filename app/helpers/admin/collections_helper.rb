module Admin::CollectionsHelper
  def collection_sortable_columns
    {
      'Name' => 'name',
      'Active' => 'active'
    }
  end

  def collection_table_headers
    [
      'Name', 'Active', 'Products', 'Created At', 'Actions',
    ]
  end

  def render_collection_table_headers(params)
    current_sort, current_direction = params[:sort_by].present? ? params[:sort_by].rpartition('_').values_at(0, 2) : [nil, nil]
    current_direction ||= 'desc'

    headers = collection_table_headers
    sortable = collection_sortable_columns

    headers.map do |header|
      text_align = header == 'Actions' ? 'text-right' : (header == 'Active' || header == 'Products' ? 'text-center' : 'text-left')
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
