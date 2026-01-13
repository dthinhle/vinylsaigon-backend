module Admin::CategoriesHelper
  # Returns the mapping of sortable headers to column names
  def category_sortable_columns
    {
      'Title' => 'title',
      'Slug' => 'slug',
      'Is Root' => 'is_root',
      'Parent' => 'parent_id',
      'Created At' => 'created_at'
    }
  end

  # Returns the ordered list of all headers for the categories table
  def category_table_headers
    [
      'Title', 'Slug', 'Is Root', 'Parent', 'Created At', 'Actions',
    ]
  end

  # Renders the table headers with sorting links where applicable
  # Uses material-icons for direction indicators (no SVG)
  def render_category_table_headers(params)
    current_sort, current_direction = params[:sort_by].present? ? params[:sort_by].rpartition('_').values_at(0, 2) : [nil, nil]
    current_direction ||= 'desc'
    headers = category_table_headers
    sortable = category_sortable_columns

    headers.map do |header|
      if sortable[header]
        col = sortable[header]
        dir = (current_sort == col && current_direction == 'asc') ? 'desc' : 'asc'
        class_name = 'px-4 py-2 text-xs font-medium text-gray-500 uppercase'
        if col == 'is_root'
          class_name << ' text-center'
        else
          class_name << ' text-left'
        end

        content_tag :th, class: class_name do
          link_to(
            "#{header}#{current_sort == col ? (current_direction == 'asc' ? ' ▲' : ' ▼') : ''}".html_safe,
            url_for(request.query_parameters.merge(sort_by: [col, dir].join('_'), page: nil)),
            class: "hover:underline #{current_sort == col ? 'text-gray-950' : ''}"
          )
        end
      else
        text_align = header == 'Actions' ? 'text-right' : 'text-left'
        content_tag :th, header, class: "px-4 py-2 #{text_align} text-xs font-medium text-gray-500 uppercase"
      end
    end.join.html_safe
  end
end
