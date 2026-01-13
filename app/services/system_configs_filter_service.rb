# frozen_string_literal: true

#
# Service to apply filters for SystemConfig collections.
# Mirrors the filtering pattern used by PromotionUsagesFilterService.
class SystemConfigsFilterService
  attr_reader :params, :errors

  # Allowed sortable columns mapping: key -> trusted DB column
  SORTABLE_COLUMNS = {
    'name' => 'system_configs.name',
    'value' => 'system_configs.value',
    'created_at' => 'system_configs.created_at',
    'updated_at' => 'system_configs.updated_at'
  }.freeze

  # Prebuilt order expressions to avoid dynamic SQL interpolation (Brakeman-safe).
  ORDER_EXPRESSIONS = {
    'name' => { 'asc' => Arel.sql('system_configs.name asc'), 'desc' => Arel.sql('system_configs.name desc') },
    'value' => { 'asc' => Arel.sql('system_configs.value asc'), 'desc' => Arel.sql('system_configs.value desc') },
    'created_at' => { 'asc' => Arel.sql('system_configs.created_at asc'), 'desc' => Arel.sql('system_configs.created_at desc') },
    'updated_at' => { 'asc' => Arel.sql('system_configs.updated_at asc'), 'desc' => Arel.sql('system_configs.updated_at desc') }
  }.freeze

  def initialize(scope:, params: nil)
    @scope = scope || SystemConfig.all
    if params.respond_to?(:permitted?) && !params.permitted?
      raise ArgumentError, 'Unpermitted parameters passed to SystemConfigsFilterService'
    end

    @params = (params || {}).to_h.symbolize_keys rescue {}

    if @params[:sort_by].present?
      sort_parts = @params[:sort_by].split('_')
      @params[:direction] = sort_parts.pop
      @params[:sort] = sort_parts.join('_')
    end

    @errors = []
  end

  # Public API: returns an ActiveRecord::Relation with filters applied.
  def call
    results
  end

  private

  def results
    scope = @scope

    # Extract nested q param or top-level fallbacks
    q_param = @params[:q]

    name_query = if q_param.is_a?(Hash)
                   (q_param[:name] || q_param['name']).to_s.presence
    end
    name_query ||= @params[:name].presence

    value_query = if q_param.is_a?(Hash)
                    (q_param[:value] || q_param['value']).to_s.presence
    end
    value_query ||= @params[:value].presence

    # Case-insensitive wildcard search (use LOWER + LIKE for compatibility)
    if name_query.present?
      pattern = "%#{name_query.to_s.downcase}%"
      scope = scope.where('LOWER(system_configs.name) LIKE ?', pattern)
    end

    if value_query.present?
      pattern = "%#{value_query.to_s.downcase}%"
      scope = scope.where('LOWER(system_configs.value) LIKE ?', pattern)
    end

    # Ordering: allow safe ordering by a small whitelist of logical keys mapped to trusted DB columns.
    sort = nil
    direction = nil
    if q_param.is_a?(Hash)
      sort = (q_param[:sort] || q_param['sort']).to_s.presence
      direction = (q_param[:direction] || q_param['direction']).to_s.presence
    end
    sort ||= @params[:sort].to_s.presence
    direction ||= @params[:direction].to_s.presence

    dir = %w[asc desc].include?(direction&.downcase) ? direction.downcase : 'desc'

    if sort.present? && ORDER_EXPRESSIONS.key?(sort.to_s)
      scope = scope.order(ORDER_EXPRESSIONS[sort.to_s][dir] || ORDER_EXPRESSIONS[sort.to_s]['desc'])
    else
      scope = scope.order(Arel.sql('system_configs.created_at desc')) if scope.order_values.blank?
    end

    scope
  end
end
