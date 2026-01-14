class Admin::ProductDataTransferController < Admin::BaseController
  before_action :check_export_lock, only: [:generate_export, :export_recent]

  def export
    @selected_products = []
    @initial_products = Product.order(updated_at: :desc)
                              .includes(:category)
                              .limit(50)
                              .select(:id, :name, :sku, :category_id)
                              .map { |p| { id: p.id, name: p.name, sku: p.sku, category: p.category&.title } }
  end

  def generate_export
    product_ids = params[:product_ids] || []

    if product_ids.empty?
      render json: { error: 'No products selected' }, status: :unprocessable_entity
      return
    end

    set_export_lock

    begin
      result = ProductExportService.call(product_ids: product_ids)

      send_data result[:data],
                type: 'application/gzip',
                disposition: "download; filename=#{result[:filename]}"
    ensure
      clear_export_lock
    end
  rescue StandardError => e
    clear_export_lock
    Rails.logger.error "Export error: #{e.message}\n#{e.backtrace.join("\n")}"
    render json: { error: "Export failed: #{e.message}" }, status: :internal_server_error
  end

  def export_recent
    hours = params[:hours]&.to_i || 6

    unless [6, 24, 48].include?(hours)
      render json: { error: 'Invalid hours parameter' }, status: :unprocessable_entity
      return
    end

    set_export_lock

    begin
      result = ProductExportService.call_recent(hours: hours)

      send_data result[:data],
                type: 'application/gzip',
                disposition: "download; filename=#{result[:filename]}"
    ensure
      clear_export_lock
    end
  rescue StandardError => e
    clear_export_lock
    Rails.logger.error "Export recent error: #{e.message}\n#{e.backtrace.join("\n")}"
    render json: { error: "Export failed: #{e.message}" }, status: :internal_server_error
  end

  def import
    @import_options = {
      mode: 'upsert',
      auto_create_categories: false,
      auto_create_brands: false
    }
    check_existing_import
  end

  def process_import
    unless params[:file].present?
      render json: { error: 'No file uploaded' }, status: :unprocessable_entity
      return
    end

    import_options = {
      mode: params[:mode] || 'upsert',
      auto_create_categories: params[:auto_create_categories] == '1',
      auto_create_brands: params[:auto_create_brands] == '1'
    }

    import_id = SecureRandom.uuid
    Rails.cache.write('product_import_progress', { status: 'processing', progress: 0, total: 0, import_id: import_id }, expires_in: 1.hour)
    session[:import_in_progress] = true

    sanitized_filename = File.basename(params[:file].original_filename)
    tmp_file_path = Rails.root.join('tmp', "import_#{import_id}_#{sanitized_filename}")
    FileUtils.cp(params[:file].path, tmp_file_path)

    ProductImportJob.perform_later(
      file_path: tmp_file_path.to_s,
      import_id: import_id,
      import_options: import_options
    )

    render json: { message: 'Import started' }
  rescue StandardError => e
    Rails.logger.error "Import error: #{e.message}\n#{e.backtrace.join("\n")}"
    render json: { error: "Import failed: #{e.message}" }, status: :internal_server_error
  end

  def import_progress
    progress = Rails.cache.read('product_import_progress')

    if progress.nil?
      session.delete(:import_in_progress)
      render json: { error: 'Import not found' }, status: :not_found
      return
    end

    if progress[:status] == 'completed' || progress[:status] == 'error'
      session.delete(:import_in_progress)
    end

    render json: progress
  end

  private

  def check_existing_import
    return unless session[:import_in_progress]

    progress = Rails.cache.read('product_import_progress')
    if progress && progress[:status] == 'processing'
      @import_in_progress = true
    else
      session.delete(:import_in_progress)
    end
  end

  def check_export_lock
    if Rails.cache.read('product_export_in_progress')
      render json: { error: 'Another export is already in progress. Please wait.' }, status: :locked
    end
  end

  def set_export_lock
    Rails.cache.write('product_export_in_progress', true, expires_in: 30.minutes)
  end

  def clear_export_lock
    Rails.cache.delete('product_export_in_progress')
  end
end
