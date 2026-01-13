# frozen_string_literal: true

class CategoryFilterService
  attr_reader :params, :errors, :active_filters

  ALLOWED_FILTERS = {
    q: String,
    is_root: :boolean,
    parent_id: Integer
  }.freeze

  def initialize(relation = Category.all, params = {})
    @relation = relation || Category.all
    if params.respond_to?(:permitted?) && !params.permitted?
      raise ArgumentError, 'Unpermitted parameters passed to CategoryFilterService'
    end
    @params = params.to_h.symbolize_keys

    if @params[:sort_by].present?
      sort_parts = @params[:sort_by].split('_')
      @params[:direction] = sort_parts.pop
      @params[:sort] = sort_parts.join('_')
    end

    @errors = []
    @active_filters = {}
    validate_and_normalize
  end

  # Returns an ActiveRecord::Relation ready for pagination
  def call
    return @relation.none unless valid?

    scope = @relation

    if (q = @active_filters[:q]).present?
      scope = scope.where('title ILIKE ?', "%#{q}%")
    end

    if @active_filters.key?(:is_root)
      scope = scope.where(is_root: @active_filters[:is_root])
    end

    if (parent = @active_filters[:parent_id]).present?
      scope = scope.where(parent_id: parent)
    end

    # Sorting
    sort_param = @params[:sort].to_s
    dir_param = @params[:direction].to_s.presence || 'desc'

    if sort_param.present?
      col = sort_param
      dir = dir_param

      allowed = %w[title slug is_root parent_id created_at]
      if allowed.include?(col)
        # Use explicit SQL ORDER to preserve direction string
        scope = scope.order("#{col} #{dir}")
      else
        scope = scope.order(title: :asc)
      end
    else
      scope = scope.order(title: :asc)
    end

    scope
  end

  # Compatibility helper returning [relation, active_filters, errors]
  def apply
    [call, active_filters, errors]
  end

  def valid?
    @errors.empty?
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

    case type
    when :boolean
      ActiveModel::Type::Boolean.new.cast(value)
    when Integer
      Integer(value)
    when String
      value.to_s
    else
      value
    end
  end
end
