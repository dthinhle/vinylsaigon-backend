class VersionChangeFormatterService
  INTERVAL_SECONDS = 5

  def self.call(versions)
    new(versions).call
  end

  def initialize(versions)
    @versions = versions
  end

  def call
    formatted = format_versions_with_changes
    group_by_entity_and_interval(formatted)
  end

  private

  def format_versions_with_changes
    admin_ids = @versions.filter_map(&:whodunnit).map(&:to_i).uniq
    admins = Admin.where(id: admin_ids).index_by(&:id)

    @versions
      .filter_map { |version| format_version(version, admins) }
  end

  def format_version(version, admins)
    changes = parse_changes(version.object_changes)
    return nil if changes.blank?

    item = version.item
    entity_type = version.item_type

    {
      version: version,
      event: version.event,
      entity_type: entity_type,
      entity_name: entity_label(item, version, entity_type),
      entity_id: version.item_id,
      admin_name: admin_name(version.whodunnit, admins),
      created_at: version.created_at,
      interval_key: interval_key(version.created_at),
      changes: changes,
      display_changes: changes.except('updated_at', 'created_at').first(3),
      total_changes: changes.size
    }
  end

  def group_by_entity_and_interval(formatted)
    grouped = formatted.group_by { |item| [item[:entity_id], item[:interval_key]] }

    grouped.map do |(entity_id, interval_key), items|
      first_item = items.first
      all_changes = items.each_with_object({}) { |item, memo| memo.merge!(item[:changes]) }
      filtered_changes = all_changes.except('updated_at', 'created_at')

      {
        version: first_item[:version],
        event: items.map { |i| i[:event].capitalize }.uniq.join(', '),
        entity_type: first_item[:entity_type],
        entity_name: first_item[:entity_name],
        entity_id: first_item[:entity_id],
        admin_name: items.map { |i| i[:admin_name] }.uniq.join(', '),
        created_at: first_item[:created_at],
        changes: all_changes,
        display_changes: filtered_changes.first(3).to_h,
        total_changes: filtered_changes.size,
        count: items.size
      }
    end.sort_by { |item| item[:created_at] }.reverse
  end

  def interval_key(timestamp)
    (timestamp.to_i / INTERVAL_SECONDS) * INTERVAL_SECONDS
  end

  def entity_label(item, version, entity_type)
    return "#{entity_type} ##{version.item_id} (deleted)" if item.blank?

    case entity_type
    when 'Product'
      "#{item.name} (SKU: #{item.sku})"
    when 'Blog'
      item.title
    else
      item.to_s
    end
  end

  def parse_changes(object_changes)
    return {} if object_changes.blank?

    YAML.safe_load(
      object_changes,
      permitted_classes: [Symbol, Time, Date, ActiveSupport::TimeWithZone, ActiveSupport::TimeZone, BigDecimal],
      aliases: true
    ) || {}
  rescue StandardError
    {}
  end

  def admin_name(whodunnit, admins)
    return 'System' if whodunnit.blank?

    admin = admins[whodunnit.to_i]
    admin&.name || "Admin ##{whodunnit}"
  end
end
