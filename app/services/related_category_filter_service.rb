# frozen_string_literal: true

class RelatedCategoryFilterService
  def initialize(params, scope)
    @params = params.to_h.symbolize_keys

    if @params[:sort_by].present?
      sort_parts = @params[:sort_by].split('_')
      @params[:direction] = sort_parts.pop
      @params[:sort] = sort_parts.join('_')
    end

    @scope = scope
  end

  def call
    filtered_scope = @scope

    # Search by category names
    if @params[:q].present?
      search_term = "%#{@params[:q]}%"
      filtered_scope = filtered_scope.joins(
        'JOIN categories cat1 ON cat1.id = related_categories.category_id',
        'JOIN categories cat2 ON cat2.id = related_categories.related_category_id'
      ).where(
        'cat1.title ILIKE ? OR cat2.title ILIKE ?',
        search_term, search_term
      )
    end

    # Filter by specific category
    if @params[:category_id].present?
      filtered_scope = filtered_scope.where(
        'category_id = ? OR related_category_id = ?',
        @params[:category_id], @params[:category_id]
      )
    end

    # Filter by weight
    if @params[:weight].present?
      filtered_scope = filtered_scope.where(weight: @params[:weight])
    end

    # Filter by weight range
    if @params[:min_weight].present?
      filtered_scope = filtered_scope.where('weight >= ?', @params[:min_weight])
    end

    if @params[:max_weight].present?
      filtered_scope = filtered_scope.where('weight <= ?', @params[:max_weight])
    end

    # Sort
    sort_column = @params[:sort].presence || 'created_at'
    sort_direction = @params[:direction].presence&.downcase == 'asc' ? 'asc' : 'desc'

    case sort_column
    when 'category'
      filtered_scope = filtered_scope.joins(
        'JOIN categories cat1 ON cat1.id = related_categories.category_id'
      ).order("cat1.title #{sort_direction}")
    when 'related_category'
      filtered_scope = filtered_scope.joins(
        'JOIN categories cat2 ON cat2.id = related_categories.related_category_id'
      ).order("cat2.title #{sort_direction}")
    when 'weight', 'created_at', 'updated_at'
      filtered_scope = filtered_scope.order("#{sort_column} #{sort_direction}")
    else
      filtered_scope = filtered_scope.order("created_at #{sort_direction}")
    end

    filtered_scope
  end
end
