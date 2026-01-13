module Admin::RedirectionMappingsHelper
  # Returns the mapping of sortable headers to column names
  def redirection_mapping_sortable_columns
    {
      'Old Slug' => 'old_slug',
      'New Slug' => 'new_slug',
      'Active' => 'active'
    }
  end

  # Returns the ordered list of all headers for the redirection mappings table
  def redirection_mapping_table_headers
    [
      'Old Slug', 'New Slug', 'Active', 'Actions',
    ]
  end

  # Renders the table headers with sorting links where applicable
  def render_redirection_mapping_table_headers(params)
    current_sort, current_direction = params[:sort_by].present? ? params[:sort_by].rpartition('_').values_at(0, 2) : [nil, nil]
    current_direction ||= 'desc'

    headers = redirection_mapping_table_headers
    sortable = redirection_mapping_sortable_columns

    headers.map do |header|
      if sortable[header]
        col = sortable[header]
        dir = (current_sort == col && current_direction == 'asc') ? 'desc' : 'asc'
        class_name = 'p-2 text-xs font-medium text-gray-500 uppercase'
        if col == 'active'
          class_name << ' text-center'
        else
          class_name << ' text-left'
        end

        content_tag :th, class: class_name do
          link_to(
            "#{header}#{current_sort == col ? (current_direction == 'asc' ? ' ▲' : ' ▼') : ''}".html_safe,
            url_for(params.permit!.to_h.merge(sort_by: [col, dir].join('_'), page: nil)),
            class: "hover:underline #{current_sort == col ? 'text-gray-950' : ''}"
          )
        end
      else
        text_align = header == 'Actions' ? 'text-right' : 'text-left'
        content_tag :th, header, class: "px-2 py-2 #{text_align} text-xs font-medium text-gray-500 uppercase"
      end
    end.join.html_safe
  end
end
