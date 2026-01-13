# frozen_string_literal: true

class BrandFilterService
  attr_reader :params, :errors, :active_filters

  ALLOWED_FILTERS = {
    q: String,
    name: String,
    slug: String,
    created_after: Date,
    created_before: Date,
    sort: String,
    direction: String,
    page: Integer,
    per_page: Integer,
    flags: Array
  }.freeze

  def initialize(params = {}, relation = nil)
    @relation = relation || Brand.all
    if params.respond_to?(:permitted?) && !params.permitted?
      raise ArgumentError, 'Unpermitted parameters passed to BrandFilterService'
    end
    @params = params.to_h.symbolize_keys
    @errors = []
    @active_filters = {}
    validate_and_normalize
  end

  # Returns an ActiveRecord::Relation of filtered brands
  def results
    return @relation.none unless valid?

    scope = @relation

    # Simple search for name or slug (qualified to avoid ambiguity when joined)
    if (q = @active_filters[:q]).present?
      scope = scope.where("#{Brand.table_name}.name ILIKE :q OR #{Brand.table_name}.slug ILIKE :q", q: "%#{q}%")
    end

    ALLOWED_FILTERS.each do |key, _type|
      next if key == :q
      value = @active_filters[key]
      next if value.nil?

      case key
      when :name
        scope = scope.where("#{Brand.table_name}.name ILIKE ?", "%#{value}%")
      when :slug
        scope = scope.where("#{Brand.table_name}.slug ILIKE ?", "%#{value}%")
      when :created_after
        scope = scope.where("#{Brand.table_name}.created_at >= ?", value)
      when :created_before
        scope = scope.where("#{Brand.table_name}.created_at <= ?", value)
      when :flags
        # Only apply flags filtering if the model actually has a flags column
        has_flags = (scope.respond_to?(:column_names) && scope.column_names.include?('flags')) || Brand.column_names.include?('flags')
        if has_flags
          scope = scope.where("#{Brand.table_name}.flags && ARRAY[?]::varchar[]", Array(value))
        end
      end
    end

    # Sorting logic - whitelist keys and build Arel order nodes to avoid SQL injection
    t = Brand.arel_table
    sort_key = @params[:sort].presence_in(%w[name slug created_at]) || 'created_at'
    sort_direction = @params[:direction].to_s == 'asc' ? :asc : :desc

    order_node =
      case sort_key
      when 'name' then sort_direction == :asc ? t[:name].asc : t[:name].desc
      when 'slug' then sort_direction == :asc ? t[:slug].asc : t[:slug].desc
      else # created_at
        sort_direction == :asc ? t[:created_at].asc : t[:created_at].desc
      end

    scope = scope.order(order_node)

    scope
  end

  def valid?
    @errors.empty?
  end

  # For compatibility with usages expecting [results, active_filters, errors]
  def apply
    [results, active_filters, errors]
  end

  private

  def validate_and_normalize
    ALLOWED_FILTERS.each do |key, type|
      raw_value = @params[key]
      next if raw_value.nil? || raw_value == ''

      begin
        value = normalize_value(raw_value, type)
        @active_filters[key] = value
      rescue ArgumentError, TypeError
        @errors << "Invalid value for #{key}: #{raw_value}"
      end
    end
  end

  def normalize_value(value, type)
    return value if type == :boolean && !!value == value
    return value if value.is_a?(type)

    case type
    when :boolean
      ActiveModel::Type::Boolean.new.cast(value)
    when Array
      # Accept comma-separated string or array
      value.is_a?(Array) ? value : value.to_s.split(',').map(&:strip)
    else
      case type.name
      when 'Float'
        Float(value)
      when 'Integer'
        Integer(value)
      when 'Date'
        Date.parse(value)
      when 'String'
        value.to_s
      else
        value
      end
    end
  end
end
