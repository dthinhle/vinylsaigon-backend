# frozen_string_literal: true

class VideoUploadService
  MAX_FILE_SIZE = 30.megabytes
  ALLOWED_CONTENT_TYPES = ['video/mp4', 'video/webm', 'video/quicktime'].freeze
  ALLOWED_EXTENSIONS = ['.mp4', '.webm', '.mov'].freeze

  def self.call(params)
    new(params).call
  end

  def initialize(params)
    @file = params[:file]
  end

  def call
    if @file.blank?
      return { success: false, error: 'No file provided' }
    end

    validate_file!
    blob = attach_to_storage
    { success: true, blob: blob }
  rescue StandardError => e
    Rails.logger.error("VideoUploadService error: #{e.message}\n#{e.backtrace.join("\n")}")
    { success: false, error: e.message }
  end

  private

  def validate_file!
    validate_size!
    validate_content_type!
    validate_extension!
  end

  def validate_size!
    if @file.size > MAX_FILE_SIZE
      raise StandardError, "File size exceeds maximum allowed (#{MAX_FILE_SIZE / 1.megabyte}MB)"
    end
  end

  def validate_content_type!
    content_type = @file.content_type
    unless ALLOWED_CONTENT_TYPES.include?(content_type)
      raise StandardError, 'Invalid file type. Allowed types: mp4, webm, mov'
    end
  end

  def validate_extension!
    filename = @file.original_filename
    extension = File.extname(filename).downcase
    unless ALLOWED_EXTENSIONS.include?(extension)
      raise StandardError, "Invalid file extension. Allowed extensions: #{ALLOWED_EXTENSIONS.join(', ')}"
    end
  end

  def attach_to_storage
    blob = ActiveStorage::Blob.create_and_upload!(
      io: @file.tempfile,
      filename: @file.original_filename,
      content_type: @file.content_type
    )
    blob
  end
end
