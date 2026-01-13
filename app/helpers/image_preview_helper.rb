module ImagePreviewHelper
  # Build a JSON string suitable for embedding in data-image-preview-existing-images-value
  # record - ActiveRecord object
  # attachment - symbol name of the attachment on record (default :image)
  # single - whether attachment is a single has_one_attached (true) or has_many_attached (false)
  def image_preview_data_for(record, attachment: :image, single: true)
    images = []
    return h(images.to_json) unless record.respond_to?(attachment)

    att = record.public_send(attachment)
    if att.respond_to?(:attached?) && att.attached?
      if single
        # For single attachment, use the underlying blob id so the server can purge that specific blob
        blob = att.blob
        images << { id: blob.id, url: rails_blob_path(blob, only_path: true) } if blob
      else
        att.each do |img|
          # img may be a blob or attachment; try to use blob id when available
          blob_id = img.respond_to?(:blob) ? img.blob.id : img.id
          img_url = url_for(img)
          images << { id: blob_id, url: img_url }
        end
      end
    elsif record.is_a?(ProductVariant) && attachment == :product_images
      # Use ProductImage model for variants
      record.product_images.order(position: :asc).each do |product_image|
        if product_image.image.attached?
          img_url = url_for(product_image.image)
          images << {
            id: product_image.id,  # Use ProductImage ID, not blob ID
            url: img_url,
            position: product_image.position
          }
        end
      end
    end

    h(images.to_json)
  end
end
