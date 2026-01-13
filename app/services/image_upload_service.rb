require 'open-uri'
require 'tempfile'

class ImageUploadService
  class DownloadError < StandardError; end

  MAX_DOWNLOAD_SIZE = 50.megabytes
  DOWNLOAD_TIMEOUT = 10

  def self.call(params)
    new(params).call
  end

  def initialize(params)
    @file = params[:file]
    @url = params[:url]
  end

  def call
    if @url.present?
      process_url
    elsif @file.present?
      process_file
    else
      { success: false, error: 'No file or URL provided' }
    end
  rescue DownloadError => e
    { success: false, error: e.message }
  rescue StandardError => e
    Rails.logger.error("ImageUploadService error: #{e.message}\n#{e.backtrace.join("\n")}")
    { success: false, error: 'Upload failed' }
  end

  private

  def process_url
    cache_hit = false
    temp_path = download_from_url(@url)
    cache_hit = @cache_hit # Set by download_from_url

    file = File.open(temp_path, 'rb')
    attach_metadata(file, @url)
    result = ImageSanitizerService.call(file)
    file.close
    File.delete(temp_path) if File.exist?(temp_path) && !cache_hit # Don't delete cache files

    # Add cache info to result
    result[:cache_hit] = cache_hit if result[:success]
    result
  rescue StandardError => e
    file&.close
    File.delete(temp_path) if temp_path && File.exist?(temp_path) && !cache_hit
    raise e
  end

  def process_file
    ImageSanitizerService.call(@file)
  end

  def download_from_url(url)
    validate_url!(url)

    # Check cache first
    cache_path = cache_path_for_url(url)
    if File.exist?(cache_path)
      @cache_hit = true
      Rails.logger.info("[ImageUpload] Cache HIT: #{url}")
      return cache_path.to_s
    end

    @cache_hit = false
    Rails.logger.info("[ImageUpload] Cache MISS, downloading: #{url}")

    temp_dir = Rails.root.join('tmp', 'image_downloads')
    FileUtils.mkdir_p(temp_dir)

    temp_path = temp_dir.join("download_#{SecureRandom.hex(8)}#{extract_extension(url)}")

    File.open(temp_path, 'wb') do |file|
      URI.open(
        url,
        read_timeout: DOWNLOAD_TIMEOUT,
        # Headers that bypass Cloudflare and other bot protection
        'User-Agent' => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36',
        'Accept' => 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
        'Accept-Language' => 'en-US,en;q=0.9',
        'Cache-Control' => 'max-age=0',
        'Sec-CH-UA' => '"Chromium";v="142", "Brave";v="142", "Not_A Brand";v="99"',
        'Sec-CH-UA-Mobile' => '?0',
        'Sec-CH-UA-Platform' => '"macOS"',
        'Sec-Fetch-Dest' => 'document',
        'Sec-Fetch-Mode' => 'navigate',
        'Sec-Fetch-Site' => 'none',
        'Sec-Fetch-User' => '?1',
        'Sec-GPC' => '1',
        'Upgrade-Insecure-Requests' => '1',
        content_length_proc: ->(size) {
          raise DownloadError, "File size exceeds maximum allowed (#{MAX_DOWNLOAD_SIZE / 1.megabyte}MB)" if size && size > MAX_DOWNLOAD_SIZE
        }
      ) do |downloaded|
        IO.copy_stream(downloaded, file)
      end
    end

    # Move to cache after successful download
    FileUtils.mv(temp_path, cache_path)

    cache_path.to_s
  rescue OpenURI::HTTPError => e
    File.delete(temp_path) if temp_path && File.exist?(temp_path)
    error_msg = e.message
    # Check if it's a Cloudflare block or bot protection
    if error_msg.include?('403') || error_msg.include?('Forbidden')
      raise DownloadError, '403 Forbidden - likely bot protection (Cloudflare/firewall)'
    else
      raise DownloadError, "HTTP error: #{error_msg}"
    end
  rescue Timeout::Error
    File.delete(temp_path) if temp_path && File.exist?(temp_path)
    raise DownloadError, 'Download timeout'
  rescue StandardError => e
    File.delete(temp_path) if temp_path && File.exist?(temp_path)
    raise DownloadError, "Download failed: #{e.message}"
  end

  def cache_path_for_url(url)
    cache_dir = Rails.root.join('tmp', 'migration_images')
    FileUtils.mkdir_p(cache_dir)

    cache_key = Digest::MD5.hexdigest(url)
    extension = extract_extension(url)
    cache_dir.join("#{cache_key}#{extension}")
  end

  def validate_url!(url)
    uri = URI.parse(url)
    unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
      raise DownloadError, 'Invalid URL scheme. Only HTTP and HTTPS are allowed'
    end
  rescue URI::InvalidURIError
    raise DownloadError, 'Invalid URL format'
  end

  def extract_extension(url)
    uri = URI.parse(url)
    path = uri.path
    ext = File.extname(path)
    ext.empty? ? '.jpg' : ext
  rescue StandardError
    '.jpg'
  end

  def attach_metadata(file, url)
    uri = URI.parse(url)
    filename = File.basename(uri.path)
    filename = 'image.jpg' if filename.empty? || filename == '/'

    file.define_singleton_method(:original_filename) { filename }
    file.define_singleton_method(:content_type) do
      case File.extname(filename).downcase
      when '.png' then 'image/png'
      when '.gif' then 'image/gif'
      when '.webp' then 'image/webp'
      else 'image/jpeg'
      end
    end
  end
end
