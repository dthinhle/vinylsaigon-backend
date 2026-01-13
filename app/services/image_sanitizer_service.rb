class ImageSanitizerService
  class ValidationError < StandardError; end

  MAX_DIMENSION = 60000
  MAX_FILE_SIZE = 50.megabytes
  ALLOWED_TYPES = %w[jpeg png webp gif avif heif].freeze

  def self.call(file)
    new(file).call
  end

  def initialize(file)
    @file = file
  end

  def call
    validate_file_presence!
    validate_file_size!
    temp_path = nil
    sanitize_and_process(temp_path)
  rescue ValidationError => e
    Rails.logger.info("ImageSanitizer validation error: #{e.message}")
    { success: false, error: e.message }
  rescue StandardError => e
    Rails.logger.error("ImageSanitizer unexpected error: #{e.message}\n#{e.backtrace.join("\n")}")
    { success: false, error: 'Image processing failed' }
  ensure
    File.delete(temp_path) if temp_path && File.exist?(temp_path)
  end

  private

  def validate_file_presence!
    raise ValidationError, 'No file provided' if @file.nil?
  end

  def validate_file_size!
    return unless @file.respond_to?(:size)
    raise ValidationError, "File size exceeds maximum allowed (#{MAX_FILE_SIZE / 1.megabyte}MB)" if @file.size > MAX_FILE_SIZE
  end

  def sanitize_and_process(temp_path)
    temp_path = create_temp_file
    image = decode_image(temp_path)
    validate_dimensions!(image)
    validate_type!(image)

    sanitized_buffer = strip_and_reencode(image)
    sanitized_io = StringIO.new(sanitized_buffer)

    blob = ActiveStorage::Blob.create_and_upload!(
      io: sanitized_io,
      filename: sanitized_filename(image),
      content_type: output_mime_type(image)
    )

     File.unlink(temp_path) if File.exist?(temp_path)
    { success: true, blob: blob }
  end

  def decode_image(temp_path)
    Vips::Image.new_from_file(temp_path, access: :sequential)
  rescue Vips::Error => e
    Rails.logger.error("ImageSanitizer decode error: #{e.message}")
    raise ValidationError, 'Invalid or corrupted image file'
  end

  def create_temp_file
    temp_dir = Rails.root.join('tmp', 'image_sanitizer')
    FileUtils.mkdir_p(temp_dir)

    temp_path = temp_dir.join("sanitize_#{SecureRandom.hex(8)}#{file_extension}")

    File.open(temp_path, 'wb') do |file|
      file.write(@file.read)
    end

    @file.rewind if @file.respond_to?(:rewind)
    temp_path.to_s
  end

  def file_extension
    return '.jpg' unless @file.respond_to?(:original_filename)
    ext = File.extname(@file.original_filename)
    ext.empty? ? '.jpg' : ext
  end

  def validate_dimensions!(image)
    # TODO: handle resize
    if image.width > MAX_DIMENSION || image.height > MAX_DIMENSION
      raise ValidationError, "Image dimensions exceed maximum allowed (#{MAX_DIMENSION}px)"
    end
  end

  def validate_type!(image)
    loader = image.get('vips-loader').downcase.gsub('load', '')
    unless ALLOWED_TYPES.include?(loader)
      raise ValidationError, "Unsupported image type: #{loader}"
    end
  end

  def strip_and_reencode(image)
    loader = image.get('vips-loader').downcase.gsub('load', '')
    ext = format_extension(loader)
    image.write_to_buffer(".#{ext}", strip: true)
  end

  def format_extension(loader)
    case loader
    when 'jpeg', 'jpg', 'jfif'
      'jpg'
    when 'png'
      'png'
    when 'webp'
      'webp'
    when 'gif'
      'gif'
    else
      'jpg'
    end
  end

  def output_mime_type(image)
    loader = image.get('vips-loader').downcase.gsub('load', '')
    case format_extension(loader)
    when 'png'
      'image/png'
    when 'gif'
      'image/gif'
    when 'webp'
      'image/webp'
    else
      'image/jpeg'
    end
  end

  def sanitized_filename(image)
    base_name = if @file.respond_to?(:original_filename)
                  File.basename(@file.original_filename, '.*')
    else
                  'image'
    end
    loader = image.get('vips-loader').downcase.gsub('load', '')
    ext = format_extension(loader)
    "#{base_name}_sanitized.#{ext}"
  end
end
