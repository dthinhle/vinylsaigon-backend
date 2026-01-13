# Downloads external images from Lexical content, stores them via ActiveStorage, and replaces URLs.
# Processes Lexical JSON format with nested node structures.
# Side effects: Creates ActiveStorage blobs, updates model content field, may fail on network/validation errors.
class ContentImageProcessorJob < ApplicationJob
  include ContentImageProcessorHelper

  queue_as :background
  sidekiq_options retry: 3, dead: true

  MAX_FILE_SIZE = 5 * 1024 * 1024

  def perform(model_type, model_id, content_hash = nil)
    model = model_type.constantize.find(model_id)

    if content_hash && !content_changed?(model, content_hash)
      Rails.logger.info("ContentImageProcessorJob: Skipping #{model_type} #{model_id} - content unchanged")
      return
    end

    Rails.logger.info("ContentImageProcessorJob: Processing images for #{model_type} #{model_id}")

    fields = content_fields_for(model)
    return if fields.empty?

    url_to_blob_map = {}

    fields.each do |field|
      content = parse_content(model.send(field))
      next unless content

      images = extract_external_images(content['root'])
      next if images.empty?

      Rails.logger.info("ContentImageProcessorJob: Found #{images.size} external images in #{field}")

      images.each do |image_url|
        next if url_to_blob_map.key?(image_url)

        begin
          blob = download_and_attach_image(image_url, model)
          url_to_blob_map[image_url] = rails_blob_url(blob) if blob
        rescue SecurityError => e
          Rails.logger.error("ContentImageProcessorJob: Security error for #{image_url}: #{e.message}")
        rescue StandardError => e
          Rails.logger.error("ContentImageProcessorJob: Failed to process image #{image_url}: #{e.message}")
        end
      end
    end

    return if url_to_blob_map.empty?

    update_model_content(model, fields, url_to_blob_map)

    Rails.logger.info("ContentImageProcessorJob: Completed for #{model_type} #{model_id}, processed #{url_to_blob_map.size} images")
  end

  private

  def content_fields_for(model)
    case model
    when Blog
      [:content]
    when Product
      [:description, :short_description]
    else
      model.respond_to?(:content) ? [:content] : []
    end
  end

  def content_changed?(model, expected_hash)
    fields = content_fields_for(model)
    content_values = fields.map { |field| model.send(field) }.join
    current_hash = Digest::SHA256.hexdigest(content_values)
    current_hash == expected_hash
  end

  def download_and_attach_image(url, model)
    validate_url_safety(url)

    uri = URI.parse(url)
    response = Net::HTTP.get_response(uri)

    return nil unless response.is_a?(Net::HTTPSuccess)

    content_type = response['content-type']
    return nil unless content_type&.start_with?('image/')

    body = response.body
    if body.bytesize > MAX_FILE_SIZE
      Rails.logger.warn("ContentImageProcessorJob: Image too large (#{body.bytesize} bytes) for #{url}")
      return nil
    end

    raw_filename = File.basename(uri.path).presence || "image_#{SecureRandom.hex(8)}.jpg"
    filename = sanitize_filename(raw_filename)

    io = StringIO.new(body)
    blob = ActiveStorage::Blob.create_and_upload!(
      io: io,
      filename: filename,
      content_type: content_type
    )

    model.content_images.attach(blob)
    blob
  rescue URI::InvalidURIError => e
    Rails.logger.error("ContentImageProcessorJob: Invalid URL #{url}: #{e.message}")
    nil
  rescue StandardError => e
    Rails.logger.error("ContentImageProcessorJob: Failed to download image #{url}: #{e.message}")
    nil
  end

  def update_model_content(model, fields, url_map)
    fields.each do |field|
      content = parse_content(model.send(field))
      next unless content

      updated_content = replace_image_urls(content, url_map)
      model.update!(field => updated_content)
    end
  end

  def replace_image_urls(content, url_map)
    content = content.deep_dup
    replace_in_node(content['root'], url_map)
    content
  end

  def replace_in_node(node, url_map)
    return unless node.is_a?(Hash)

    if node['type'] == 'image' && node['src']
      new_url = url_map[node['src']]
      node['src'] = new_url if new_url
    end

    if node['children'].is_a?(Array)
      node['children'].each do |child|
        replace_in_node(child, url_map)
      end
    end
  end

  def rails_blob_url(blob)
    Rails.application.routes.url_helpers.rails_blob_url(blob, only_path: true)
  end
end
