# frozen_string_literal: true

module ImageAttachable
  extend ActiveSupport::Concern

  # Handle ProductImage model with position ordering
  def update_product_images(variant, product_images_attributes = nil, new_images = nil, positions = nil)
    changed = false
    # Handle position updates for existing ProductImage records
    if product_images_attributes.present?
      product_images_attributes.each do |_idx, attrs|
        if attrs[:_destroy].to_s == '1' || attrs[:_destroy].to_s == 'true'
          product_image = variant.product_images.find_by(id: attrs[:id])
          product_image&.destroy
          changed = true
        end
      end
    end

    new_created_images = []

    # Handle new image attachments with positions
    if new_images.present?
      new_images = Array(new_images).reject(&:blank?)
      positions = Array(positions).compact if positions.present?

      new_images.each_with_index do |image, index|
        next unless image.present?

        product_image = variant.product_images.build
        if positions.present? && positions[index].present?
          position_index = positions[index].to_i
          product_image.insert_at(position_index)
        else
          product_image.move_to_bottom
          position_index = product_image.position
        end
        product_image.image.attach(image)
        changed = true

        new_created_images << { product_image: product_image, index: position_index }
      end
    end

    if product_images_attributes.present?
      product_images_attributes.each do |_idx, attrs|
        if attrs[:id].present? && attrs[:position].present?
          product_image = variant.product_images.find_by(id: attrs[:id])
          product_image&.update(position: attrs[:position])
          changed = true
        end
      end
    end

    image_count = variant.product_images.count
    new_created_images.each do |entry|
      product_image = entry[:product_image]
      index = entry[:index]

      if index
        product_image.position = index
      else
        product_image.position = image_count + 1
        image_count += 1
      end
      product_image.save if product_image.changed?
      changed = true
    end

    changed
  end

  # Enhanced image handling with duplicate detection and removal using ProductImage model
  def update_images_advanced(record, remove_image_ids = nil, new_images = nil)
    # Handle image removal via ProductImage records
    if remove_image_ids.present?
      images_to_remove = Array(remove_image_ids)
      if record.respond_to?(:product_images)
        record.product_images.where(id: images_to_remove).destroy_all
        Rails.logger.info("Removed #{images_to_remove.length} ProductImages from #{record.class.name} #{record.id}")
      else
        # Fallback to direct blob removal for non-ProductImage models
        record.images.where(blob_id: images_to_remove).each(&:purge)
        Rails.logger.info("Removed #{images_to_remove.length} images from #{record.class.name} #{record.id}")
      end
    end

    # Handle new image attachments with duplicate detection
    if new_images.present?
      new_images = Array(new_images).compact
      images_attached = 0

      if record.respond_to?(:product_images)
        # Use ProductImage model with positioning
        existing_checksums = get_product_image_checksums(record.product_images)
        max_position = record.product_images.maximum(:position) || 0

        new_images.each_with_index do |image, index|
          next unless image.present?

          # Skip if this image already exists (compare by checksum)
          if image.respond_to?(:read)
            image_data = image.read
            image.rewind if image.respond_to?(:rewind)
            image_checksum = Digest::MD5.hexdigest(image_data)

            if existing_checksums.include?(image_checksum)
              Rails.logger.info("Skipping duplicate image for #{record.class.name} #{record.id}")
              next
            end
          end

          position = max_position + index + 1
          product_image = record.product_images.create!(position: position)
          product_image.image.attach(image)
          images_attached += 1
        end
      else
        # Fallback to direct attachment for non-ProductImage models
        existing_checksums = record.images.attached? ? get_image_checksums(record.images) : Set.new

        new_images.each do |image|
          next unless image.present?

          if image.respond_to?(:read)
            image_data = image.read
            image.rewind if image.respond_to?(:rewind)
            image_checksum = Digest::MD5.hexdigest(image_data)

            if existing_checksums.include?(image_checksum)
              Rails.logger.info("Skipping duplicate image for #{record.class.name} #{record.id}")
              next
            end
          end

          record.images.attach(image)
          images_attached += 1
        end
      end

      Rails.logger.info("Attached #{images_attached} new images to #{record.class.name} #{record.id}")
    end
  end

  # Legacy method for backward compatibility
  def update_images(record, remove_image_ids, new_images)
    if remove_image_ids.present?
      record.images.where(blob_id: remove_image_ids).each(&:purge_later)
    end

    if new_images.present?
      if new_images.is_a?(Array)
        new_images.each { |img| record.images.attach(img) }
      else
        record.images.attach(new_images)
      end
    end
  end

  private

  # Gets checksums of existing ProductImage records for duplicate detection
  def get_product_image_checksums(product_images)
    checksums = Set.new
    product_images.each do |product_image|
      next unless product_image.image.attached? && product_image.image.blob.present?

      checksum = product_image.image.blob.checksum || begin
        image_data = product_image.image.download
        Digest::MD5.hexdigest(image_data)
      rescue StandardError => e
        Rails.logger.warn("Could not compute checksum for ProductImage #{product_image.id}: #{e.message}")
        nil
      end

      checksums.add(checksum) if checksum
    end
    checksums
  end

  # Gets checksums of existing attached images for duplicate detection (legacy)
  def get_image_checksums(images)
    checksums = Set.new
    images.each do |image|
      if image.blob.present?
        checksum = image.blob.checksum || begin
          image_data = image.download
          Digest::MD5.hexdigest(image_data)
        rescue StandardError => e
          Rails.logger.warn("Could not compute checksum for image #{image.id}: #{e.message}")
          nil
        end

        checksums.add(checksum) if checksum
      end
    end
    checksums
  end
end
