# frozen_string_literal: true

# ProductVersionService manages version history and reversion for products and their variants.
# It uses PaperTrail to track changes and supports reverting products to previous states.
#
# Usage:
#   # Get version history
#   versions = ProductVersionService.versions_for(product, limit: 10)
#
#   # Revert to a specific version
#   ProductVersionService.revert_to(product, transaction_id)
#
class ProductVersionService
  class RevertError < StandardError; end

  class << self
    def versions_for(product, limit: 10)
      versions = PaperTrail::Version
        .where(product_id: product.id)
        .order(created_at: :desc)
        .limit(limit)
        .group_by(&:transaction_id)

      admins = Admin.where(id: versions.values.flatten.map(&:whodunnit).uniq).index_by(&:id)
      versions.map do |transaction_id, grouped_versions|
        first_version = grouped_versions.first
        admin = admins[first_version.whodunnit.to_i]
        admin_string = admin ? "#{admin.name} (#{admin.email})" : 'System'
        changed_columns = collect_changed_columns(grouped_versions)

        {
          transaction_id: transaction_id,
          created_at: first_version.created_at,
          event: first_version.event,
          admin_email: admin_string,
          admin_id: first_version.whodunnit,
          changes_count: grouped_versions.size,
          changed_columns: changed_columns,
          versions: grouped_versions.map do |v|
            {
              id: v.id,
              item_type: v.item_type,
              item_id: v.item_id,
              event: v.event,
              changeset: parse_changeset(v)
            }
          end
        }
      end
    end

    def revert_to(product, transaction_id)
      versions = PaperTrail::Version
        .where(product_id: product.id, transaction_id: transaction_id)
        .order(created_at: :desc)

      raise RevertError, 'No versions found for this transaction' if versions.empty?

      ActiveRecord::Base.transaction do
        PaperTrail.request(whodunnit: PaperTrail.request.whodunnit) do
          PaperTrail.request.controller_info = {
            transaction_id: SecureRandom.uuid
          }

          versions.each do |version|
            revert_version(version, product)
          end

          product.reload
        end
      end

      product
    end

    private

    def collect_changed_columns(versions)
      columns = Set.new
      versions.each do |version|
        changeset = parse_changeset(version)
        columns.merge(changeset.keys) if changeset.present?
      end
      columns.to_a.sort
    end

    def parse_changeset(version)
      return {} if version.object_changes.blank?

      begin
        YAML.safe_load(version.object_changes, permitted_classes: [Symbol, Time, Date, ActiveSupport::TimeWithZone, ActiveSupport::TimeZone, BigDecimal])
      rescue StandardError => e
        Rails.logger.warn("Failed to parse changeset for version #{version.id}: #{e.message}")
        {}
      end
    end

    def revert_version(version, product)
      reified = version.reify

      if reified.nil?
        handle_create_revert(version, product)
      else
        reified.save!
        Rails.logger.info("ProductVersionService revert_version: Reverted #{version.item_type}##{version.item_id}")
      end
    end

    def handle_create_revert(version, product)
      case version.item_type
      when 'Product'
        raise RevertError, 'Cannot revert product creation - would delete the product'
      when 'ProductVariant'
        variant = ProductVariant.find_by(id: version.item_id)
        if variant && variant.product_id == product.id
          variant.destroy!
          Rails.logger.info("ProductVersionService revert_version: Destroyed ProductVariant##{version.item_id} (reverting creation)")
        end
      end
    end
  end
end
