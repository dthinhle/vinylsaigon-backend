module Admin::BlogsHelper
  # Constants for blog table configuration - loaded once by Rails
  BLOG_SORTABLE_COLUMNS = {
    'Id' => 'id',
    'Title' => 'title',
    'Slug' => 'slug',
    'Category' => 'category_id',
    'Author' => 'author_id',
    'Published At' => 'published_at',
    'Status' => 'status',
    'Created At' => 'created_at',
    'View Count' => 'view_count'
  }.freeze

  BLOG_TABLE_HEADERS = [
    'Title', 'Slug', 'Category', 'Author', 'Created At', 'Published At', 'Status', 'Actions',
  ].freeze

  # Returns the mapping of sortable headers to column names
  def blog_sortable_columns
    BLOG_SORTABLE_COLUMNS
  end

  # Returns the ordered list of all headers for the blogs table
  def blog_table_headers
    BLOG_TABLE_HEADERS
  end

  # Renders the table headers with sorting links where applicable
  def render_blog_table_headers(params)
    current_sort, current_direction = params[:sort_by].present? ? params[:sort_by].rpartition('_').values_at(0, 2) : [nil, nil]
    current_direction ||= 'desc'

    headers = BLOG_TABLE_HEADERS
    sortable = BLOG_SORTABLE_COLUMNS

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
