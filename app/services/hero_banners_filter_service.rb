# frozen_string_literal: true

class HeroBannersFilterService
  # Columns allowed for sorting mapped to their fully-qualified names
  SORTABLE_COLUMNS = {
    'created_at' => 'hero_banners.created_at',
    'main_title' => 'hero_banners.main_title'
  }.freeze

  def initialize(scope:, params: {})
    if params.respond_to?(:permitted?) && !params.permitted?
      raise ArgumentError, 'Unpermitted parameters passed to HeroBannersFilterService'
    end
    @scope = scope
    @params = (params || {}).to_h.symbolize_keys

    if @params[:sort_by].present?
      sort_parts = @params[:sort_by].split('_')
      @params[:direction] = sort_parts.pop
      @params[:sort] = sort_parts.join('_')
    end
  end


  # Returns an Array matching controller expectations:
  # [ActiveRecord::Relation, active_filters_hash, filter_errors_array, pagy_object_or_nil]
  def call
    relation = @scope
    relation = apply_search(relation)
    relation = apply_exact_filters(relation)
    relation = apply_order(relation)

    active_filters = {}
    active_filters[:q] = @params[:q] if @params[:q].present?
    active_filters[:main_title] = @params[:main_title] if @params[:main_title].present?

    filter_errors = []
    pagy = nil

    [relation, active_filters, filter_errors, pagy]
  end

  private

  def apply_search(scope)
    q = @params[:q]
    return scope unless q.present?

    pattern = "%#{q.to_s.downcase}%"
    scope.where('LOWER(hero_banners.main_title) LIKE ? OR LOWER(hero_banners.description) LIKE ?', pattern, pattern)
  end

  def apply_exact_filters(scope)
    if @params[:main_title].present?
      scope = scope.where(main_title: @params[:main_title])
    end

    if @params[:sub_title].present?
      scope = scope.where(sub_title: @params[:sub_title])
    end

    scope
  end

  def apply_order(scope)
    sort = resolve_sort_column(@params[:sort])
    direction = @params[:direction].to_s.downcase == 'asc' ? 'asc' : 'desc'

    if sort
      scope.order("#{sort} #{direction}")
    else
      scope.order('hero_banners.created_at DESC')
    end
  end

  # Returns fully-qualified column name for allowed sort columns or nil
  def resolve_sort_column(column)
    return SORTABLE_COLUMNS['created_at'] if column.blank?
    SORTABLE_COLUMNS[column.to_s]
  end
end
