# frozen_string_literal: true

#
# Service to apply filters for PromotionUsage collections.
# Extracted from Admin::PromotionUsagesFilterService and moved here so controllers can use a shared service.
class PromotionUsagesFilterService
  attr_reader :params, :errors

  # Allowed sortable columns mapping: key -> [db_column, optional_join_symbol]
  # Keys are trusted and static to avoid SQL injection; joins applied when needed.
  SORTABLE_COLUMNS = {
    'id' => ['promotion_usages.id', nil],
    'created_at' => ['promotion_usages.created_at', nil],
    'active' => ['promotion_usages.active', nil],
    'promotion_code' => ['promotions.code', :promotion],
    'user_email' => ['users.email', :user]
  }.freeze

  # Prebuilt order expressions to avoid dynamic SQL interpolation (Brakeman-safe).
  ORDER_EXPRESSIONS = {
    'id' => { 'asc' => Arel.sql('promotion_usages.id asc'), 'desc' => Arel.sql('promotion_usages.id desc') },
    'created_at' => { 'asc' => Arel.sql('promotion_usages.created_at asc'), 'desc' => Arel.sql('promotion_usages.created_at desc') },
    'active' => { 'asc' => Arel.sql('promotion_usages.active asc'), 'desc' => Arel.sql('promotion_usages.active desc') },
    'promotion_code' => { 'asc' => Arel.sql('promotion_code asc'), 'desc' => Arel.sql('promotion_code desc') },
    'user_email' => { 'asc' => Arel.sql('user_email asc'), 'desc' => Arel.sql('user_email desc') }
  }.freeze

  def initialize(scope:, params: nil, promotion: nil)
    @scope = scope || PromotionUsage.all
    if params.respond_to?(:permitted?) && !params.permitted?
      raise ArgumentError, 'Unpermitted parameters passed to PromotionUsagesFilterService'
    end

    @params = (params || {}).to_h.symbolize_keys rescue {}

    if @params[:sort_by].present?
      sort_parts = @params[:sort_by].split('_')
      @params[:direction] = sort_parts.pop
      @params[:sort] = sort_parts.join('_')
    end

    @promotion = promotion
    @errors = []
  end

  # Public API: returns an ActiveRecord::Relation with filters applied.
  def call
    results
  end

  private

  def results
    scope = @scope

    # If a Promotion instance is provided, scope to that promotion to support nested routes.
    scope = scope.where(promotion_id: @promotion.id) if @promotion.present?

    # Active filter: support the UI's 'only_active' / 'only_inactive' sentinel values.
    case @params[:active]
    when 'only_active'
      scope = scope.where(active: true)
    when 'only_inactive'
      scope = scope.where(active: false)
    else
      # Also accept explicit boolean true/false if provided.
      if [true, false].include?(@params[:active])
        scope = scope.where(active: @params[:active])
      end
    end

    # Direct filter by user_id (if passed)
    scope = scope.where(user_id: @params[:user_id]) if @params[:user_id].present?

    email_query = @params[:user_email].presence
    code_query  = @params[:promotion_code].presence

    if email_query.present? || code_query.present?
      joins = []
      joins << :user if email_query.present?
      joins << :promotion if code_query.present?
      scope = scope.left_outer_joins(*joins).distinct

      if email_query.present?
        pattern = "%#{email_query}%"
        scope = scope.where("users.email ILIKE :q OR (promotion_usages.metadata->>'created_by') ILIKE :q", q: pattern)
      end

      if code_query.present?
        pattern = "%#{code_query}%"
        scope = scope.where('promotions.code ILIKE :q', q: pattern)
      end
    end

    # Ordering: allow safe ordering by a small whitelist of logical keys mapped to trusted DB columns.
    # Mapping values are static (never derived from user input) and some order keys require joining related tables.
    # If a join is required for ordering, we apply a left_outer_joins so records without the association remain visible.

    sort = @params[:sort].to_s.presence
    direction = @params[:direction].to_s.presence

    direction = %w[asc desc].include?(direction&.downcase) ? direction.downcase : 'desc'

    if sort.present? && SORTABLE_COLUMNS.key?(sort.to_s)
      column, join_sym = SORTABLE_COLUMNS[sort.to_s]

      if join_sym
        scope = scope.left_outer_joins(join_sym).distinct

        scope = scope.select('promotion_usages.*')

        case sort.to_s
        when 'promotion_code'
          scope = scope.select('promotions.code AS promotion_code') unless scope.select_values.any? { |s| s.to_s.include?('promotion_code') }
        when 'user_email'
          scope = scope.select('users.email AS user_email') unless scope.select_values.any? { |s| s.to_s.include?('user_email') }
        end
      end

      if ORDER_EXPRESSIONS.key?(sort.to_s)
        scope = scope.reorder(ORDER_EXPRESSIONS[sort.to_s][direction] || ORDER_EXPRESSIONS[sort.to_s]['desc'])
      end
    end

    scope = scope.order(created_at: :desc) if scope.order_values.blank?

    scope
  end
end
