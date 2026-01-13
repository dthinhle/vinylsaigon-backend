json.blogs do
  json.array! @blogs do |blog|
    json.partial! 'blog_info', locals: { blog: blog }
  end
end

json.pagination do
  # Get total pages defensively to support both classic and offset pagy
  total_pages = @pagy.respond_to?(:pages) ? @pagy.pages :
                (@pagy.respond_to?(:count) && @pagy.respond_to?(:limit) ?
                 (@pagy.count.to_f / @pagy.limit).ceil : 0)

  json.current_page @pagy.page
  json.total_pages total_pages
  json.total_count @pagy.count
  json.next_page (@pagy.page < @pagy.pages ? @pagy.page + 1 : nil)
  json.prev_page (@pagy.page > 1 ? @pagy.page - 1 : nil)
  json.first_page @pagy.page == 1
  json.last_page @pagy.page == @pagy.pages
  json.per_page @pagy.limit
end
