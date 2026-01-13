class FilterChipRenderer
  def initialize(filter_params, filter_labels)
    @filter_params = filter_params
    @filter_labels = filter_labels
    @record_cache = {}
  end

  def render_chips
    chips = []
    processed_keys = Set.new
    preload_records

    @filter_params.each do |key, value|
      value = value.map(&:presence).compact if value.is_a?(Array)
      next if value.blank? || key == 'page'
      next if processed_keys.include?(key)

      if key == 'sort_by'
        chips << build_sort_by_chip(value)
        processed_keys.add('sort_by')
      elsif key == 'direction' && @filter_params['sort'].present?
        next
      elsif key == 'sort' && @filter_params['direction'].present?
        chips << build_sort_chip
        processed_keys.add('sort')
        processed_keys.add('direction')
      elsif key.end_with?('_ids') && value.is_a?(Array)
        value.each do |v|
          chips << build_relationship_chip(key, v)
        end
        processed_keys.add(key)
      elsif key == 'parent_id'
        chips << build_relationship_chip('category_id', value)
        processed_keys.add(key)
      elsif key.end_with?('_id')
        chips << build_relationship_chip(key, value)
        processed_keys.add(key)
      else
        chips << build_simple_chip(key, value)
        processed_keys.add(key)
      end
    end

    chips
  end

  private

  def preload_records
    @filter_params.each do |key, value|
      next unless key.end_with?('_ids', '_id') || key == 'parent_id'

      model_name = if key == 'parent_id'
        'Category'
      else
        key.sub(/_ids?$/, '').classify
      end

      next unless Object.const_defined?(model_name)

      ids = value.is_a?(Array) ? value : [value]
      ids = ids.compact.map(&:to_i)

      next if ids.empty?

      begin
        model_class = model_name.constantize
        records = model_class.where(id: ids).index_by(&:id)
        @record_cache[model_name] ||= {}
        @record_cache[model_name].merge!(records)
      rescue NameError
      end
    end
  end

  def build_sort_by_chip(value)
    parts = value.split('_')
    direction = parts.pop
    field = parts.join('_')
    display_value = "#{field.humanize} - #{direction.upcase}"

    {
      key: 'sort_by',
      label: @filter_labels['sort_by'] || 'Sort',
      value: display_value,
      remove_params: ['sort_by']
    }
  end

  def build_sort_chip
    sort_value = @filter_params['sort']
    direction_value = @filter_params['direction']
    display_value = "#{sort_value.humanize} - #{direction_value.upcase}"

    {
      key: 'sort',
      label: @filter_labels['sort'] || 'Sort',
      value: display_value,
      remove_params: ['sort', 'direction']
    }
  end

  def build_relationship_chip(key, value)
    model_name = key.sub(/_ids?$/, '').classify
    display_value = resolve_relationship_value(model_name, value)

    {
      key: key.end_with?('_ids') ? "#{key}_#{value}" : key,
      label: @filter_labels[key] || key.to_s.humanize,
      value: display_value,
      remove_params: key.end_with?('_ids') ? ["#{key}[]", value.to_s] : [key],
      is_array_item: key.end_with?('_ids')
    }
  end

  def build_simple_chip(key, value)
    display_value = format_value(value)

    {
      key: key,
      label: @filter_labels[key] || key.to_s.humanize,
      value: display_value,
      remove_params: [key],
      is_array: value.is_a?(Array)
    }
  end

  def resolve_relationship_value(model_name, id)
    return id unless Object.const_defined?(model_name)

    record = @record_cache.dig(model_name, id.to_i)
    return id unless record

    [:title, :name, :email].each do |attr|
      return record.public_send(attr) if record.respond_to?(attr)
    end

    id
  rescue NameError, ActiveRecord::RecordNotFound
    id
  end

  def format_value(value)
    case value
    when Array
      value.join(', ')
    when 'true'
      'Yes'
    when 'false'
      'No'
    else
      value.to_s
    end
  end
end
