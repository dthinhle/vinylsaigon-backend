# frozen_string_literal: true

class BlogFilterService
  SORTABLE_FIELDS = %w[
    id title slug category_id author_id published_at status view_count created_at
  ].freeze

  FILTERABLE_FIELDS = [
    :q, :slug, :status, :sort_by,
  ].freeze

  attr_reader :params, :relation

  def initialize(params, relation = Blog.all)
    permitted = params.permit(*FILTERABLE_FIELDS)
    @params = permitted.to_h.with_indifferent_access

    if @params[:sort_by].present?
      sort_parts = @params[:sort_by].split('_')
      @params[:direction] = sort_parts.pop
      @params[:sort] = sort_parts.join('_')
    end

    @relation = relation
  end

  def call
    blogs = relation
    blogs = apply_search_filter(blogs)
    blogs = apply_slug_filter(blogs)
    blogs = apply_status_filter(blogs)
    blogs = apply_sorting(blogs)
    blogs
  end

  private

  def apply_search_filter(blogs)
    return blogs unless params[:q].present?

    blogs.where(
      'title ILIKE :q',
      q: "%#{params[:q]}%"
    )
  end

  def apply_slug_filter(blogs)
    return blogs unless params[:slug].present?

    blogs.where('slug ILIKE ?', "%#{params[:slug]}%")
  end

  def apply_status_filter(blogs)
    return blogs unless params[:status].present? && Blog.statuses.key?(params[:status])

    blogs.where(status: params[:status])
  end

  def apply_sorting(blogs)
    sort_field = params[:sort]
    direction = params[:direction] == 'asc' ? 'asc' : 'desc'

    if sort_field.present? && SORTABLE_FIELDS.include?(sort_field)
      blogs.order("#{sort_field} #{direction}")
    else
      blogs.order(created_at: :desc)
    end
  end
end
